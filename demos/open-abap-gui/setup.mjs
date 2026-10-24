import {readFileSync} from "node:fs";
import {SQLiteDatabaseClient} from "@abaplint/database-sqlite";

// The flights come from the CAP sample data of this repository, so the ABAP
// report and the Fiori app show the same rows.
const dataFolder = new URL("../../db/data/", import.meta.url);

function readCsv(name) {
  const [header, ...lines] = readFileSync(new URL(name, dataFolder), "utf8").trim().split(/\r?\n/);
  const columns = header.split(";");
  return lines.map(line => Object.fromEntries(line.split(";").map((value, i) => [columns[i], value])));
}

function quote(value) {
  return "'" + String(value).replaceAll("'", "''") + "'";
}

function seedStatements() {
  const airlines = readCsv("sap.fe.cap.travel-Airline.csv").map(a =>
    `INSERT INTO 'zcarr_demo' VALUES (${[a.AirlineID, a.Name, a.CurrencyCode_code].map(quote).join(", ")});`);
  const flights = readCsv("sap.fe.cap.travel-Flight.csv").map(f =>
    `INSERT INTO 'zflight_demo' VALUES (${[
      quote(f.AirlineID),
      quote(f.ConnectionID),
      quote(f.FlightDate.replaceAll("-", "")),
      f.Price,
      quote(f.CurrencyCode_code),
      quote(f.PlaneType),
      f.MaximumSeats,
      f.OccupiedSeats,
    ].join(", ")});`);
  return [...airlines, ...flights].join("\n");
}

export async function setupDatabase(abap, schemas, insert) {
  const database = new SQLiteDatabaseClient();
  abap.context.databaseConnections.DEFAULT = database;
  await database.connect();
  await database.execute(schemas.sqlite);
  await database.execute(insert);
  await database.execute(seedStatements());
}
