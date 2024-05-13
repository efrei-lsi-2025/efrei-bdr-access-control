import { defineConfig } from "drizzle-kit";

export default defineConfig({
  dialect: "postgresql",
  schema: "./src/schema.ts",
  out: "./drizzle",
  dbCredentials: {
    host: "bdr-eu-1.epsilon",
    user: "postgres",
    password: "postgres",
    database: "postgres",
  },
  schemaFilter: ["public"],
  tablesFilter: [
    "accesslog",
    "accessright",
    "building",
    "gate",
    "gategroup",
    "gatetogategroup",
    "person",
    "presencelog",
  ],
});
