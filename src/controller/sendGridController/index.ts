import { Request, Response } from "express";
import { ClassSendGridService } from "../../service/sendGridService";

export class ClassSendGridController {
	private readonly service = new ClassSendGridService();

	public sendEmailForMyBulb = async (req: Request, res: Response) => {
		try {
			const { email, name, ecole, post, message } = req.body;

			if (!email || !name || !ecole || !post || !message) {
				return res.status(400).json({ error: "Missing required fields" });
			}

			const result = await this.service.sendEmailForMyBulb({
				from: process.env.EMAIL_SENDER || "",
				to: email,
				subject: `${ecole}, ${name}, ${post}`,
				body: message,
			});

			return res.status(200).json({ data: result });
		} catch (error) {
			console.error(error);
			return res.status(500).json({ error: "Internal server error" });
		}
	};
}
