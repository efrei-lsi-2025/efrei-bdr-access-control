import { relations } from "drizzle-orm";
import {
  pgTable,
  uuid,
  timestamp,
  boolean,
  time,
  varchar,
  primaryKey,
  date,
} from "drizzle-orm/pg-core";

export const accesslog = pgTable("accesslog", {
  accesslogid: uuid("accesslogid").primaryKey().notNull(),
  badgeid: uuid("badgeid").notNull(),
  gateid: uuid("gateid").notNull(),
  accesstime: timestamp("accesstime", { mode: "string" }).notNull(),
  success: boolean("success").notNull(),
});

export const presencelog = pgTable("presencelog", {
  presencelogid: uuid("presencelogid").primaryKey().notNull(),
  badgeid: uuid("badgeid").notNull(),
  gategroupid: uuid("gategroupid").notNull(),
  entranceaccesslogid: uuid("entranceaccesslogid").notNull(),
  exitaccesslogid: uuid("exitaccesslogid"),
  elapsedtime: time("elapsedtime"),
});

export const gate = pgTable("gate", {
  gateid: uuid("gateid").primaryKey().notNull(),
});

export const person = pgTable("person", {
  badgeid: uuid("badgeid").primaryKey().notNull(),
  name: varchar("name", { length: 255 }).notNull(),
});

export const gategroup = pgTable("gategroup", {
  gategroupid: uuid("gategroupid").primaryKey().notNull(),
  name: varchar("name", { length: 255 }).notNull(),
  buildingid: uuid("buildingid")
    .notNull()
    .references(() => building.buildingid),
});

export const gatetogategroup = pgTable("gatetogategroup", {
  gatetogategroupid: uuid("gatetogategroupid").primaryKey().notNull(),
  gateid: uuid("gateid")
    .notNull()
    .references(() => gate.gateid),
  gategroupid: uuid("gategroupid")
    .notNull()
    .references(() => gategroup.gategroupid),
  direction: boolean("direction").notNull(),
});

export const building = pgTable("building", {
  buildingid: uuid("buildingid").primaryKey().notNull(),
  name: varchar("name", { length: 255 }).notNull(),
  address: varchar("address", { length: 511 }).notNull(),
});

export const accessright = pgTable(
  "accessright",
  {
    gategroupid: uuid("gategroupid")
      .notNull()
      .references(() => gategroup.gategroupid),
    badgeid: uuid("badgeid")
      .notNull()
      .references(() => person.badgeid),
    expirationdate: date("expirationdate").notNull(),
  },
  (table) => {
    return {
      accessright_pkey: primaryKey({
        columns: [table.gategroupid, table.badgeid],
        name: "accessright_pkey",
      }),
    };
  }
);

export const gategroupRelations = relations(gategroup, ({ one, many }) => ({
  building: one(building, {
    fields: [gategroup.buildingid],
    references: [building.buildingid],
  }),
  gatetogategroups: many(gatetogategroup),
  accessrights: many(accessright),
}));

export const buildingRelations = relations(building, ({ many }) => ({
  gategroups: many(gategroup),
}));

export const gatetogategroupRelations = relations(
  gatetogategroup,
  ({ one }) => ({
    gategroup: one(gategroup, {
      fields: [gatetogategroup.gategroupid],
      references: [gategroup.gategroupid],
    }),
    gate: one(gate, {
      fields: [gatetogategroup.gateid],
      references: [gate.gateid],
    }),
  })
);

export const gateRelations = relations(gate, ({ many }) => ({
  gatetogategroups: many(gatetogategroup),
}));

export const accessrightRelations = relations(accessright, ({ one }) => ({
  person: one(person, {
    fields: [accessright.badgeid],
    references: [person.badgeid],
  }),
  gategroup: one(gategroup, {
    fields: [accessright.gategroupid],
    references: [gategroup.gategroupid],
  }),
}));

export const personRelations = relations(person, ({ many }) => ({
  accessrights: many(accessright),
}));
