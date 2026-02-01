import { Request, Response } from "express";
import { ClassSendGridService } from "../../service/sendGridService";

export class ClassSendGridController {
	private readonly service = new ClassSendGridService();

	public sendEmailForMyBulb = async (req: Request, res: Response) => {
		try {
			if (
				!req.body.email ||
				!req.body.name ||
				!req.body.ecole ||
				!req.body.post ||
				!req.body.message
			) {
				throw new Error("Missing required fields");
			}
			const { email, name, ecole, post, message } = req.body;
			const result = await this.service.sendEmailForMyBulb({
				from: process.env.EMAIL_SENDER || "", //expediteur
				to: process.env.EMAIL_SENDER || "", //destinataire
				subject: `${ecole}, ${name}, ${post} -> ${email}`,
				replyTo: email,
				body: message,
			});
			return res.status(200).json({ data: result });
		} catch (error) {
			console.error(error);
			return res.status(500).json({ error: "Internal server error" });
		}
	};
}
