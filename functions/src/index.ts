import {createHash} from "crypto";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {initializeApp} from "firebase-admin/app";
import {DocumentSnapshot, getFirestore, FieldValue} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

type Audience =
  | "all_teachers"
  | "all_parents"
  | "all_users"
  | "parents_of_teacher"
  | "teacher_and_parents_of_teacher";

interface BroadcastRequest {
  title?: string;
  body?: string;
  audience?: Audience;
  teacherId?: string;
}

async function assertAdmin(uid: string): Promise<void> {
  const doc = await db.collection("users").doc(uid).get();
  const data = doc.data();
  if (!doc.exists || data?.role !== "admin") {
    throw new HttpsError("permission-denied", "Yalnızca admin bu işlemi yapabilir.");
  }
  if (data?.isActive === false) {
    throw new HttpsError("permission-denied", "Hesabınız pasif durumda.");
  }
}

async function parentIdsForTeacher(teacherId: string): Promise<Set<string>> {
  const snap = await db
    .collection("students")
    .where("teacherId", "==", teacherId)
    .get();
  const parentIds = new Set<string>();
  snap.docs.forEach((doc) => {
    const ids = (doc.data().parentIds as string[] | undefined) ?? [];
    ids.forEach((id) => parentIds.add(id));
  });
  return parentIds;
}

async function resolveTargetUids(
  audience: Audience,
  teacherId?: string,
): Promise<Set<string>> {
  const uids = new Set<string>();

  if (audience === "all_teachers" || audience === "all_users") {
    const snap = await db
      .collection("users")
      .where("role", "==", "teacher")
      .get();
    snap.docs.forEach((doc) => uids.add(doc.id));
  }

  if (audience === "all_parents" || audience === "all_users") {
    const snap = await db
      .collection("users")
      .where("role", "==", "parent")
      .get();
    snap.docs.forEach((doc) => uids.add(doc.id));
  }

  if (
    audience === "parents_of_teacher" ||
    audience === "teacher_and_parents_of_teacher"
  ) {
    if (!teacherId) {
      throw new HttpsError(
        "invalid-argument",
        "Bu hedef kitle için teacherId zorunludur.",
      );
    }
    const parents = await parentIdsForTeacher(teacherId);
    parents.forEach((id) => uids.add(id));
    if (audience === "teacher_and_parents_of_teacher") {
      uids.add(teacherId);
    }
  }

  return uids;
}

async function collectTokens(uids: Set<string>): Promise<string[]> {
  const tokens: string[] = [];
  const uidList = Array.from(uids);

  for (let i = 0; i < uidList.length; i += 10) {
    const chunk = uidList.slice(i, i + 10);
    const reads = await Promise.all(
      chunk.map((uid) => db.collection("users").doc(uid).get()),
    );
    reads.forEach((doc) => {
      if (!doc.exists) return;
      const data = doc.data() ?? {};
      const fcmTokens = (data.fcmTokens as string[] | undefined) ?? [];
      fcmTokens.forEach((token) => {
        if (token && token.length > 0) tokens.push(token);
      });
    });
  }

  return Array.from(new Set(tokens));
}

export const sendBroadcast = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
  }

  await assertAdmin(request.auth.uid);

  const data = (request.data ?? {}) as BroadcastRequest;
  const title = (data.title ?? "").trim();
  const body = (data.body ?? "").trim();
  const audience = data.audience;
  const teacherId = data.teacherId;

  if (!title || !body) {
    throw new HttpsError("invalid-argument", "Başlık ve mesaj zorunludur.");
  }
  if (!audience) {
    throw new HttpsError("invalid-argument", "Hedef kitle zorunludur.");
  }

  const targetUids = await resolveTargetUids(audience, teacherId);
  const tokens = await collectTokens(targetUids);

  let sentCount = 0;
  const batchSize = 500;

  for (let i = 0; i < tokens.length; i += batchSize) {
    const chunk = tokens.slice(i, i + batchSize);
    if (chunk.length === 0) continue;

    const response = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: {title, body},
      data: {
        type: "system",
        audience,
      },
    });
    sentCount += response.successCount;
  }

  const now = FieldValue.serverTimestamp();

  const auditRef = db.collection("admin_broadcasts").doc();
  await auditRef.set({
    adminId: request.auth.uid,
    title,
    body,
    audience,
    teacherId: teacherId ?? null,
    targetUserCount: targetUids.size,
    sentCount,
    tokenCount: tokens.length,
    createdAt: now,
  });

  const uidList = Array.from(targetUids);
  const chunkSize = 400;
  for (let i = 0; i < uidList.length; i += chunkSize) {
    const chunk = uidList.slice(i, i + chunkSize);
    const batch = db.batch();
    chunk.forEach((uid) => {
      const ref = db.collection("notifications").doc();
      batch.set(ref, {
        userId: uid,
        title,
        body,
        type: "system",
        isRead: false,
        createdAt: now,
        source: "admin_broadcast",
      });
    });
    await batch.commit();
  }

  return {
    success: true,
    targetUserCount: targetUids.size,
    tokenCount: tokens.length,
    sentCount,
    broadcastId: auditRef.id,
  };
});

const MESSAGE_STUDENT_CAP = 200;

interface TeacherMessageRequest {
  title?: string;
  body?: string;
  teacherName?: string;
  classId?: string;
  className?: string;
  targetStudentId?: string;
}

interface TeacherPreviewRequest {
  email?: string;
}

/**
 * E-posta önizlemesi sayacı. Belge kimliği anahtarın özetidir; e-posta yazılmaz.
 * 1 dakika / 20 istek. App Check enforce Faz 8.
 */
async function assertPreviewRateLimit(key: string): Promise<void> {
  const windowMs = 60_000;
  const maxHits = 20;
  const id = createHash("sha256").update(key).digest("hex");
  const ref = db.collection("_rate_limits").doc(`teacher_preview_${id}`);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const data = snap.data();
    const resetAt = typeof data?.resetAt === "number" ? data.resetAt : 0;
    if (!snap.exists || resetAt < now) {
      tx.set(ref, {count: 1, resetAt: now + windowMs});
      return;
    }
    const count = (typeof data?.count === "number" ? data.count : 0) + 1;
    if (count > maxHits) {
      throw new HttpsError(
        "resource-exhausted",
        "Çok fazla deneme. Lütfen bir dakika sonra tekrar deneyin.",
      );
    }
    tx.update(ref, {count});
  });
}

async function assertActiveTeacher(uid: string): Promise<void> {
  const doc = await db.collection("users").doc(uid).get();
  const data = doc.data();
  if (!doc.exists || data?.role !== "teacher") {
    throw new HttpsError("permission-denied", "Yalnızca öğretmen mesaj gönderebilir.");
  }
  if (data?.isActive === false) {
    throw new HttpsError("permission-denied", "Hesabınız pasif durumda.");
  }
}

export const sendTeacherMessage = onCall(
  {consumeAppCheckToken: false},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Oturum açmanız gerekir.");
    }
    const uid = request.auth.uid;
    await assertActiveTeacher(uid);

    const data = (request.data ?? {}) as TeacherMessageRequest;
    const title = (data.title ?? "").trim();
    const body = (data.body ?? "").trim();
    const classId = (data.classId ?? "").trim();
    const targetStudentId = (data.targetStudentId ?? "").trim();
    const teacherName = (data.teacherName ?? "").trim();
    const className = (data.className ?? "").trim();

    if (!title || !body) {
      throw new HttpsError("invalid-argument", "Başlık ve mesaj zorunludur.");
    }
    if (title.length > 120 || body.length > 2000) {
      throw new HttpsError("invalid-argument", "Başlık veya mesaj çok uzun.");
    }

    if (classId) {
      const classDoc = await db.collection("classes").doc(classId).get();
      if (!classDoc.exists || classDoc.data()?.teacherId !== uid) {
        throw new HttpsError("permission-denied", "Bu sınıf için yetkiniz yok.");
      }
    }

    const studentDocs: DocumentSnapshot[] = [];
    if (targetStudentId) {
      const studentDoc = await db.collection("students").doc(targetStudentId).get();
      if (!studentDoc.exists || studentDoc.data()?.teacherId !== uid) {
        throw new HttpsError("permission-denied", "Bu öğrenci size ait değil.");
      }
      if (classId && studentDoc.data()?.classId !== classId) {
        throw new HttpsError("invalid-argument", "Öğrenci seçilen sınıfta değil.");
      }
      studentDocs.push(studentDoc);
    } else {
      let studentQuery = db.collection("students").where("teacherId", "==", uid);
      if (classId) {
        studentQuery = studentQuery.where("classId", "==", classId);
      }
      const studentSnap = await studentQuery.limit(MESSAGE_STUDENT_CAP + 1).get();
      if (studentSnap.size > MESSAGE_STUDENT_CAP) {
        throw new HttpsError(
          "failed-precondition",
          "Bu gönderim 200 öğrenciden fazla. Daha dar bir sınıf seçin.",
        );
      }
      studentDocs.push(...studentSnap.docs);
    }

    const studentIds: string[] = [];
    const parentIds = new Set<string>();
    studentDocs.forEach((doc) => {
      studentIds.push(doc.id);
      const ids = (doc.data()?.parentIds as string[] | undefined) ?? [];
      ids.forEach((id) => {
        if (id) parentIds.add(id);
      });
    });

    const messageRef = db.collection("messages").doc();
    const now = FieldValue.serverTimestamp();
    await messageRef.set({
      teacherId: uid,
      ...(teacherName ? {teacherName} : {}),
      parentIds: Array.from(parentIds),
      studentIds,
      ...(classId ? {classId} : {}),
      ...(className ? {className} : {}),
      title,
      body,
      type: targetStudentId ? "individual" : "bulk",
      createdAt: now,
    });

    const parents = Array.from(parentIds);
    const chunkSize = 400;
    for (let i = 0; i < parents.length; i += chunkSize) {
      const chunk = parents.slice(i, i + chunkSize);
      const batch = db.batch();
      chunk.forEach((parentId) => {
        const ref = db.collection("notifications").doc();
        batch.set(ref, {
          userId: parentId,
          title,
          body,
          type: "message",
          data: {messageId: messageRef.id},
          isRead: false,
          createdAt: now,
        });
      });
      await batch.commit();
    }

    return {
      messageId: messageRef.id,
      studentCount: studentIds.length,
      parentCount: parents.length,
    };
  },
);

export const getTeacherAuthPreview = onCall(
  {
    // Enforce App Check later (Faz 8); keep callable usable for launch smoke.
    consumeAppCheckToken: false,
  },
  async (request) => {
    const email = ((request.data ?? {}) as TeacherPreviewRequest).email
      ?.trim()
      .toLowerCase();

    if (!email || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "Geçerli bir e-posta gerekir.");
    }

    const rateKey = request.auth?.uid ?? request.rawRequest.ip ?? email;
    await assertPreviewRateLimit(String(rateKey));

    const snap = await db
      .collection("users")
      .where("email", "==", email)
      .limit(1)
      .get();

    if (snap.empty) {
      return {exists: false, isTeacher: false};
    }

    const role = snap.docs[0].data()?.role as string | undefined;
    return {
      exists: true,
      isTeacher: role === "teacher",
    };
  },
);