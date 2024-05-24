import postgres from "postgres";
import { faker } from "@faker-js/faker";
import { parseArgs } from "util";

const sql = postgres(
  "postgres://postgres:postgres@bdr-eu-1.epsilon:5432/postgres"
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

const runQueries = async (name: string, promises: Promise<any>[]) => {
  let progress = 0;

  promises.forEach((promise) => {
    promise.then(() => {
      progress++;
    });
  });

  let lastProgress = 0;
  const deltaArray: number[] = [];
  let peakDelta = 0;

  const elapsed = Date.now();

  const interval = setInterval(() => {
    const progressDelta = progress - lastProgress;
    deltaArray.push(progressDelta);
    lastProgress = progress;

    if (progressDelta > peakDelta) {
      peakDelta = progressDelta;
    }

    console.log(
      `${name} - ${new Date().toISOString()} | Progress: ${progress}/${
        promises.length
      } (cur: ${progressDelta}/s - avg: ${Math.round(
        deltaArray.reduce((acc, curr) => acc + curr, 0) / deltaArray.length
      )}/s - peak: ${peakDelta}/s)`
    );
  }, 1000);

  await Promise.all(promises);

  console.log(`${name} - Elapsed: ${Date.now() - elapsed}ms`);

  clearInterval(interval);
};

// Persons

if (values.person) {
  const number = Number(values.person);

  if (!number || number < 1) {
    console.error("Invalid value for person");
    process.exit(1);
  }

  const personRecords = Array.from({ length: Number(values.person) }, () => ({
    badgeid: crypto.randomUUID(),
    region: faker.helpers.arrayElement(["EU", "US"]),
  }));

  console.log(`Created ${personRecords.length} persons`);

  await runQueries(
    "person",
    personRecords.map((person) => {
      return sql`INSERT INTO distributed.person_view ${sql(person)}`;
    })
  );

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

  await runQueries(
    "building",
    buildingRecords.map((building) => {
      return sql`INSERT INTO distributed.building_view ${sql(building)}`;
    })
  );

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

  await runQueries(
    "gategroup_view",
    gateGroups.map((gategroup) => {
      return sql`INSERT INTO distributed.gategroup_view ${sql(gategroup)}`;
    })
  );

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

  await runQueries(
    "gatetogategroup_view",
    gateGroupGates.map((gategroupgate) => {
      return sql`INSERT INTO distributed.gatetogategroup_view ${sql(
        gategroupgate
      )}`;
    })
  );

  console.log("Inserted gatetogategroup_view");
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
      expirationdate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
    };
  });

  await runQueries(
    "accessright",
    accessRights.map((accessright) => {
      return sql`INSERT INTO distributed.accessright_view ${sql(accessright)}`;
    })
  );

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
    FROM distributed.gatetogategroup_view`;

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

  await runQueries(
    "simulation",
    simulations.map((simulation) => {
      return sql`SELECT distributed.enter_workspace(${simulation.badgeid}, ${simulation.gateid})`;
    })
  );

  console.log("Simulation completed");
}
