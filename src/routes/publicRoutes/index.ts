import { Router } from "express";
import sendGridRouter from "./sendGrid";

const publicRoutes = Router();

publicRoutes.use("/send_grid", sendGridRouter);

export default publicRoutes;
