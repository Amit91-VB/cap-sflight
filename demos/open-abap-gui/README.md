# Flight report off-stack with open-abap-gui

A classic ABAP report that runs in the browser with no SAP system. It has a selection screen, a dynpro with an ALV grid, a GUI status and a transaction code. It reads the same flights as the CAP app in this repository (`db/data/sap.fe.cap.travel-Flight.csv` and `-Airline.csv`).

It uses [open-abap-gui](https://github.com/open-abap/open-abap-gui), which is work in progress. Expect gaps. See below.

## Run it

```sh
cd demos/open-abap-gui
npm install
npm start
```

Open http://localhost:3000, then start transaction `ZFLD` from the workbench or type `/nZFLD` in the command field. Set `PORT` to use another port.

The first build clones open-abap-core, express-icf-shim, open-abap-bal and open-abap-gui, so it needs network access to GitHub.

## What's in it

| File | Object |
| --- | --- |
| `reports/zflight_demo.prog.abap` | Report source: selection screen, SELECT, ALV, PBO and PAI modules |
| `reports/zflight_demo.prog.xml` | Program attributes, screen 0100 layout, GUI status `MAIN`, title, text pool |
| `reports/zflight_demo.prog.screen_0100.abap` | Screen 0100 flow logic |
| `reports/zfld.tran.xml` | Transaction `ZFLD` |
| `src/zflight_demo.tabl.xml` | Table `ZFLIGHT_DEMO`, shaped like SFLIGHT |
| `src/zcarr_demo.tabl.xml` | Table `ZCARR_DEMO`, shaped like SCARR |
| `setup.mjs` | Creates the SQLite schema and loads the CAP CSV files |
| `express.mjs` | Serves the workbench through express-icf-shim |
| `abap_transpile.json` | Config for both the converter and the transpiler |
| `tests/zfld.spec.mjs` | Playwright smoke test |
| `playwright.config.mjs` | Starts the server for the tests on port 3123 |

All ABAP files use the abapGit layout, so you can pull them into a real system with abapGit.

## How it works

1. `open-abap-gui-convert` turns the report into a class (`generated/zcl_flight_demo.clas.abap`) that the open-abap-gui host can run.
2. `abap_transpile` compiles the ABAP to JavaScript (`output/`).
3. `setup.mjs` runs before the first program and fills an in-memory SQLite database.
4. The host renders screens, the GUI status and the ALV grid as HTML.

## Commands

```sh
npm run check    # converter dry run, JSON diagnostics per statement
npm run convert  # report to class only
npm run build    # convert and transpile
npm start        # build and serve
npx open-abap-gui-convert --program ZFLIGHT_DEMO --check --diagnostics json
```

## Smoke test

`tests/zfld.spec.mjs` drives the report in Chromium with Playwright. It starts the server itself, runs the transaction and checks the selection screen, the grid, double click, the Details button and Back. It also fails on any JavaScript error in the page.

```sh
npm run install:browser   # once, downloads Chromium for Playwright
npm run test:e2e          # build, then run the tests
npm test                  # run the tests against the current build
npx playwright show-report
```

The expected rows are computed from the same CSV files the database is loaded from, so the test still holds if the sample data changes. Each test fails on its own when the behavior it covers breaks. For example, removing the `BT` workaround below fails the airline range test.

## Known gaps worked around in the report

Each workaround has a comment in the source and changes nothing on a real system.

- **Select-options.** The host passes an empty select-option as `I EQ space` and a filled low and high as `EQ` instead of `BT`. The report deletes the empty rows and sets `BT`.
- **JOIN with aliases.** The transpiler leaves `f~carrid` untranslated on the right side of `ON`. The joined SELECT returns nothing. The report reads both tables and fills the airline name from a hashed table.
