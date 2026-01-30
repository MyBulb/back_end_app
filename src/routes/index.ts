import { Router } from "express";
import publicRoutes from "./publicRoutes";

const router = Router();

router.use("/public", publicRoutes);

export default router;
