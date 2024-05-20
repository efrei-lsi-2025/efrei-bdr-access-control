import postgres from "postgres";
import { faker } from "@faker-js/faker";
import { parseArgs } from "util";

const batchSize = 5000;

const sql = postgres(
  "postgres://postgres:postgres@bdr-us-1.epsilon:5432/postgres"
);

const { values } = parseArgs({
  args: Bun.argv,
  options: {
    person: {
      type: "string",
      short: "p",
    },
    building: {
      type: "string",
      short: "b",
    },
    gate: {
      type: "string",
      short: "g",
    },
    accessright: {
      type: "boolean",
      short: "a",
      default: false,
    },
    simulation: {
      type: "boolean",
      short: "s",
      default: false,
    },
  },
  strict: true,
  allowPositionals: true,
});

// Persons

if (values.person) {
  const number = Number(values.person);

  if (!number || number < 1) {
    console.error("Invalid value for person");
    process.exit(1);
  }

  const personRecords = Array.from({ length: Number(values.person) }, () => ({
    badgeid: crypto.randomUUID(),
    name: faker.person.firstName(),
    region: faker.helpers.arrayElement(["EU", "US"]),
  }));

  for (let i = 0; i < personRecords.length; i += batchSize) {
    const recordsToInsert = personRecords.slice(i, i + batchSize);
    await sql`INSERT INTO distributed.person_view ${sql(
      personRecords.slice(i, i + batchSize)
    )}`;
    console.log(
      `Inserted ${i + recordsToInsert.length}/${personRecords.length} persons`
    );
  }

  console.log("Inserted persons");
}

if (values.building) {
  const number = Number(values.building);

  if (!number || number < 1) {
    console.error("Invalid value for building");
    process.exit(1);
  }

  const buildingRecords = Array.from(
    { length: Number(values.building) },
    () => ({
      buildingid: crypto.randomUUID(),
      name: faker.location.street(),
      address: faker.location.streetAddress(),
      region: faker.helpers.arrayElement(["EU", "US"]),
    })
  );

  for (let i = 0; i < buildingRecords.length; i += batchSize) {
    const recordsToInsert = buildingRecords.slice(i, i + batchSize);
    await sql`INSERT INTO distributed.building_view ${sql(
      buildingRecords.slice(i, i + batchSize)
    )}`;
    console.log(
      `Inserted ${i + recordsToInsert.length}/${
        buildingRecords.length
      } buildings`
    );
  }

  console.log("Inserted buildings");
}

if (values.gate) {
  const number = Number(values.gate);

  if (!number || number < 1) {
    console.error("Invalid value for gate");
    process.exit(1);
  }

  // create gategroups of 4 gates each
  // 2 gate are direction true, 2 are direction false
  const numberOfGateGroups = Math.ceil(number / 4);

  const buildings =
    await sql`SELECT buildingid FROM distributed.building_view LIMIT ${numberOfGateGroups}`;

  console.log(`Fetched ${buildings.length} buildings`);

  const gateGroups = Array.from({ length: numberOfGateGroups }, (_, i) => ({
    gategroupid: crypto.randomUUID(),
    name: `Gate Group ${i + 1}`,
    buildingid: buildings[i].buildingid,
  }));

  for (let i = 0; i < gateGroups.length; i += batchSize) {
    const recordsToInsert = gateGroups.slice(i, i + batchSize);
    await sql`INSERT INTO distributed.gategroup_view ${sql(
      gateGroups.slice(i, i + batchSize)
    )}`;
    console.log(
      `Inserted ${i + recordsToInsert.length}/${gateGroups.length} gategroups`
    );
  }

  const gates = Array.from({ length: number }, (_, i) => ({
    gateid: crypto.randomUUID(),
  }));

  const gateGroupGates = gates.map((gate, i) => {
    const gateGroup = gateGroups[Math.floor(i / 4)];
    return {
      gategroupid: gateGroup.gategroupid,
      gateid: gate.gateid,
      direction: i % 4 < 2,
    };
  });

  for (let i = 0; i < gateGroupGates.length; i += batchSize) {
    const recordsToInsert = gateGroupGates.slice(i, i + batchSize);
    await sql`INSERT INTO distributed.gate_and_gatetogategroup_view ${sql(
      gateGroupGates.slice(i, i + batchSize)
    )}`;
    console.log(
      `Inserted ${i + recordsToInsert.length}/${
        gateGroupGates.length
      } gategroupgates`
    );
  }

  console.log("Inserted gates");
}

if (values.accessright) {
  const persons =
    await sql`SELECT badgeid, region FROM distributed.person_view WHERE badgeid NOT IN (SELECT badgeid FROM distributed.accessright_view)`;

  console.log(
    `Fetched ${persons.length} persons (eu: ${
      persons.filter((p) => p.region === "EU").length
    }, us: ${persons.filter((p) => p.region === "US").length})`
  );

  const gategroups = await sql`
    SELECT gategroup.gategroupid, gategroup.buildingid, building.region 
    FROM distributed.gategroup_view AS gategroup
    INNER JOIN distributed.building_view AS building 
      ON gategroup.buildingid = building.buildingid`;

  console.log(
    `Fetched ${gategroups.length} gategroups (eu: ${
      gategroups.filter((g) => g.region === "EU").length
    }, us: ${gategroups.filter((g) => g.region === "US").length})`
  );

  const accessRights = persons.map((person, i) => {
    const randomGategroup = faker.helpers.arrayElement(
      gategroups.filter((g) => g.region === person.region)
    );
    return {
      badgeid: person.badgeid,
      gategroupid: randomGategroup.gategroupid,
      expirationdate: faker.date.future({
        years: 1,
      }),
    };
  });

  for (let i = 0; i < accessRights.length; i += batchSize) {
    const recordsToInsert = accessRights.slice(i, i + batchSize);
    await sql`INSERT INTO distributed.accessright_view ${sql(
      accessRights.slice(i, i + batchSize)
    )}`;
    console.log(
      `Inserted ${i + recordsToInsert.length}/${
        accessRights.length
      } accessrights`
    );
  }

  console.log("Inserted accessrights");
}

if (values.simulation) {
  const persons = await sql`
    SELECT person.badgeid, person.region, accessright.gategroupid 
    FROM distributed.person_view AS person
    INNER JOIN distributed.accessright_view AS accessright
      ON person.badgeid = accessright.badgeid`;

  console.log(`Fetched ${persons.length} persons`);

  const gateGroupGates = await sql`
    SELECT gategroupid, gateid, direction
    FROM distributed.gate_and_gatetogategroup_view`;

  console.log(`Fetched ${gateGroupGates.length} gategroupgates`);

  const simulationsEnter = persons.map((person, i) => {
    const gateGroupGatesForPerson = gateGroupGates.filter(
      (g) => g.gategroupid === person.gategroupid && g.direction === true
    );

    const randomGate = faker.helpers.arrayElement(gateGroupGatesForPerson);

    return {
      badgeid: person.badgeid,
      gateid: randomGate.gateid,
    };
  });

  const simulationsExit = persons.map((person, i) => {
    const gateGroupGatesForPerson = gateGroupGates.filter(
      (g) => g.gategroupid === person.gategroupid && g.direction === false
    );

    const randomGate = faker.helpers.arrayElement(gateGroupGatesForPerson);

    return {
      badgeid: person.badgeid,
      gateid: randomGate.gateid,
    };
  });

  const simulations = [...simulationsEnter];
  for (let i = 0; i < simulationsExit.length; i++) {
    simulations.splice(i * 2 + 1, 0, simulationsExit[i]);
  }

  console.log(`Created ${simulations.length} simulations`);

  for (let i = 0; i < simulations.length; i++) {
    console.log(simulations[i]);
    await sql`SELECT distributed.enter_building(${simulations[i].badgeid}, ${simulations[i].gateid})`;
    console.log(`Inserted ${i + 1}/${simulations.length} simulations`);
  }
}
