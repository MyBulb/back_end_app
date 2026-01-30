import sgMail from "@sendgrid/mail";
import dotenv from "dotenv";

export class ClassSendGridService {
	constructor() {
		dotenv.config();

		const apiKey = process.env.SENDGRID_API_KEY;

		if (!apiKey) {
			throw new Error("SENDGRID_API_KEY is missing");
		}

		sgMail.setApiKey(apiKey);
	}
	public async sendEmailForMyBulb(data: {
		from: string;
		to: string;
		subject: string;
		body: string;
	}) {
		const { from, to, subject, body } = data;
		return await this.sendEmail({ from, to, subject, text: body });
	}

	private async sendEmail({
		from,
		to,
		subject,
		text,
	}: {
		from: string;
		to: string;
		subject: string;
		text: string;
	}) {
		const [resp] = await sgMail.send({ from, to, subject, text });
		return resp.statusCode;
	}
}
