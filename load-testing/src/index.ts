import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";

import { faker } from "@faker-js/faker";

const queryClient = postgres(
  "postgres://postgres:postgres@bdr-eu-1.epsilon/postgres"
);
const db = drizzle(queryClient, { schema });
console.log(await db.query.person.findMany({}));

// create 150 person records

const personRecords = Array.from({ length: 3000 }, () => ({
  badgeid: crypto.randomUUID(),
  name: faker.person.firstName(),
}));

await db.insert(schema.person).values(personRecords).execute();
