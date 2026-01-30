import { Router } from "express";
import { ClassSendGridController } from "../../controller/sendGridController/index";

const sendGridRouter = Router();
const controller = new ClassSendGridController();

sendGridRouter.post("/from_my_bulb", controller.sendEmailForMyBulb);

export default sendGridRouter;
