import express from "express";
import {initializeABAP} from "./output/init.mjs";
import {cl_express_icf_shim} from "./output/express-icf-shim/cl_express_icf_shim.clas.mjs";

await initializeABAP();

const port = process.env.PORT ?? 3000;
const app = express();
app.use(express.raw({type: "*/*"}));
app.all("*", async function (req, res) {
  await cl_express_icf_shim.run({req, res, class: "ZCL_GG_HTTP_HANDLER"});
});
app.listen(port, () => console.log(`open-abap-gui workbench on http://localhost:${port}`));
