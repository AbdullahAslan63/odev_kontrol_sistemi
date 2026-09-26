import {readFileSync} from "node:fs";
import {dirname, resolve} from "node:path";
import {fileURLToPath} from "node:url";
import {
  assertFails,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const rules = readFileSync(resolve(root, "firestore.rules"), "utf8");

const testEnv = await initializeTestEnvironment({
  projectId: "demo-eduly-rules",
  firestore: {rules},
});

await testEnv.withSecurityRulesDisabled(async (context) => {
  const db = context.firestore();
  await db.doc("users/teacher1").set({
    role: "teacher",
    email: "teacher@eduly.app",
    isActive: true,
  });
  await db.doc("users/parent1").set({
    role: "parent",
    email: "parent@eduly.app",
    isActive: false,
  });
  await db.doc("students/other").set({
    teacherId: "teacher2",
    parentIds: [],
    name: "Başka öğrenci",
  });
});

const teacher = testEnv.authenticatedContext("teacher1").firestore();
const parent = testEnv.authenticatedContext("parent1").firestore();

await assertFails(
  teacher.doc("goals/g1").set({
    teacherId: "teacher1",
    studentId: "other",
    isActive: true,
  }),
);

await assertFails(
  parent.doc("users/parent1").update({isActive: true}),
);

await assertFails(
  teacher.doc("notifications/n1").set({
    userId: "parent1",
    title: "Başlık",
    body: "Mesaj",
    type: "message",
    isRead: false,
  }),
);

await testEnv.cleanup();
console.log("firestore rules: 3 denied writes ok");
