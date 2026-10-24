import {test, expect} from "@playwright/test";
import {readCsv} from "../setup.mjs";

// Expected rows follow the report logic over the same CSV files the database
// is loaded from: sorted by airline, flight and date, full flights dropped.
const flights = readCsv("sap.fe.cap.travel-Flight.csv")
  .map(f => ({
    carrid: f.AirlineID,
    connid: f.ConnectionID,
    fldate: f.FlightDate,
    seatsmax: Number(f.MaximumSeats),
    seatsfree: Number(f.MaximumSeats) - Number(f.OccupiedSeats),
  }))
  .filter(f => f.seatsfree > 0)
  .sort((a, b) => (a.carrid + a.connid + a.fldate).localeCompare(b.carrid + b.connid + b.fldate));

const between = (low, high) => flights.filter(f => f.carrid >= low && f.carrid <= high);
const info = f => `${f.carrid} ${f.connid} on ${f.fldate}: ${f.seatsfree} of ${f.seatsmax} seats free`;

async function runReport(page, {low = "", high = ""} = {}) {
  await page.goto("/");
  await page.locator("#ToolbarOkCode").fill("/nZFLD");
  await page.locator("#ToolbarOkCode").press("Enter");
  await expect(page.locator("#S_CARR-LOW")).toBeVisible();
  await page.locator("#S_CARR-LOW").fill(low);
  await page.locator("#S_CARR-HIGH").fill(high);
  await page.getByRole("button", {name: "Execute", exact: true}).click();
}

const grid = page => page.locator("tr.gg-grid-row");
const cell = (page, row, field) => page.locator(`tr[data-row-index="${row}"] td[data-fieldname="${field}"]`);

test.describe("ZFLD flight occupancy", () => {
  let pageErrors;

  test.beforeEach(({page}) => {
    pageErrors = [];
    page.on("pageerror", error => pageErrors.push(error.message));
  });

  test.afterEach(() => {
    expect(pageErrors).toEqual([]);
  });

  test("empty selection lists every flight with free seats", async ({page}) => {
    await runReport(page);
    await expect(page.getByText(`Flight occupancy: ${flights.length} flights`)).toBeVisible();
    await expect(grid(page)).toHaveCount(flights.length);
  });

  test("airline range low to high selects between, not equal", async ({page}) => {
    const expected = between("EA", "GA");
    await runReport(page, {low: "EA", high: "GA"});
    await expect(page.getByText(`Flight occupancy: ${expected.length} flights`)).toBeVisible();
    await expect(grid(page)).toHaveCount(expected.length);
    const carriers = await page.locator('td[data-fieldname="CARRID"]').allInnerTexts();
    expect([...new Set(carriers.map(c => c.trim()))]).toEqual([...new Set(expected.map(f => f.carrid))]);
  });

  test("airline names come from the airline table", async ({page}) => {
    const airlines = readCsv("sap.fe.cap.travel-Airline.csv");
    const first = airlines[0];
    await runReport(page, {low: first.AirlineID});
    await expect(cell(page, 1, "CARRNAME")).toHaveText(first.Name);
  });

  test("double click shows free seats of that flight", async ({page}) => {
    const expected = between("EA", "GA");
    await runReport(page, {low: "EA", high: "GA"});
    await cell(page, 2, "CONNID").dblclick();
    await expect(page.getByText(info(expected[1]))).toBeVisible();
  });

  test("Details uses the selected row", async ({page}) => {
    const expected = between("EA", "GA");
    await runReport(page, {low: "EA", high: "GA"});
    await page.locator('tr[data-row-index="5"] [data-gg-row-select]').click();
    await page.getByRole("button", {name: "Details", exact: true}).click();
    await expect(page.getByText(info(expected[4]))).toBeVisible();
  });

  test("Details without a selection asks for one", async ({page}) => {
    await runReport(page);
    await page.getByRole("button", {name: "Details", exact: true}).click();
    await expect(page.getByText("Select a flight first")).toBeVisible();
  });

  test("Back returns to the selection screen and keeps the input", async ({page}) => {
    await runReport(page, {low: "EA", high: "GA"});
    await expect(grid(page).first()).toBeVisible();
    await page.getByRole("button", {name: "Back", exact: true}).click();
    await expect(page.locator("#S_CARR-LOW")).toHaveValue("EA");
    await expect(page.locator("#S_CARR-HIGH")).toHaveValue("GA");
  });
});
