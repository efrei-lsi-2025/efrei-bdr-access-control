import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";

import { faker } from "@faker-js/faker";

const queryClient = postgres(
  "postgres://postgres:postgres@bdr-eu-1.epsilon:5432/postgres"
);
const db = drizzle(queryClient, { schema });
console.log(await db.query.person.findMany({}));

// create 150 person records

const personRecords = Array.from({ length: 1000000 }, () => ({
  badgeid: crypto.randomUUID(),
  name: faker.person.firstName(),
}));

// batch into 1000 records per insert
for (let i = 0; i < personRecords.length; i += 1000) {
  await db
    .insert(schema.person)
    .values(personRecords.slice(i, i + 1000))
    .execute();
}
