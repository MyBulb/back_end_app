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
		replyTo: string;
		body: string;
	}) {
		const { from, to, subject, body, replyTo } = data;
		return await this.sendEmail({ from, to, subject, text: body, replyTo });
	}

	private async sendEmail({
		from,
		to,
		subject,
		text,
		replyTo,
	}: {
		from: string;
		to: string;
		subject: string;
		text: string;
		replyTo?: string;
	}) {
		console.log("from", from);
		console.log("to", to);
		console.log("subject", subject);
		console.log("text", text);
		const [resp] = await sgMail.send({
			from,
			to,
			subject,
			text,
			replyTo: replyTo,
		});
		return resp.statusCode;
	}
}
