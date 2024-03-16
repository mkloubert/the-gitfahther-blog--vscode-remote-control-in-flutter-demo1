// MIT License
//
// Copyright (c) 2024 Marcel Joachim Kloubert (https://marcel.coffee)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

const {
	createServer,
	json,
	validateAjv,
} = require('@egomobile/http-server');
import * as tmp from 'tmp';
import * as vscode from 'vscode';

const {
	fs
} = vscode.workspace;

// representation of `openTextDocumentRequestBodySchema` schema
interface IOpenTextDocumentRequestBody {
	extension?: string | null;
	text: string;
}

let app: any;

// validation schema
const openTextDocumentRequestBodySchema = {
	type: 'object',
	required: [
		"text"
	],
	properties: {
		extension: {
			type: ["string", "null"]
		},
		text: {
			type: "string"
		}
	}
};

const TGF_PORT = Number(process.env.TGF_PORT?.trim() || '4000');

export async function activate(context: vscode.ExtensionContext) {
	const newApp = createServer();

	// "open editor" endpoint
	newApp.post(
		'/api/v1/editors',

		// parse input as JSON
		// and validate
		[
			json(),
			validateAjv(openTextDocumentRequestBodySchema),
		],

		async (request: any, response: any) => {
			const body = request.body as IOpenTextDocumentRequestBody;

			try {
				// extract body data
				const extension = body.extension?.trim() || undefined;
				const textData = Buffer.from(body.text, 'utf8');

				// get path for an unique tempfile
				const tempFilePath = await (() => {
					return new Promise<string>((resolve, reject) => {
						tmp.file({
							postfix: extension ? `.${extension}` : undefined
						}, (error, name) => {
							if (error) {
								reject(error);
							} else {
								resolve(name);
							}
						});
					});
				})();
				const tempFileUri = vscode.Uri.file(tempFilePath);

				// write using the VSCode filesystem API:
				// https://code.visualstudio.com/api/extension-guides/virtual-documents
				await fs.writeFile(tempFileUri, textData);

				// open and show the temp file
				await vscode.window.showTextDocument(tempFileUri);

				response.writeHead(204, {
					'Content-Type': 'text/plain; charset=UTF-8',
					'Content-Length': '0'
				});
			} catch (error) {
				const errorMessage = Buffer.from(
					String(error), 'utf8'
				);

				if (!response.headersSent) {
					response.writeHead(500, {
						'Content-Type': 'text/plain; charset=UTF-8',
						'Content-Length': String(errorMessage.length)
					});
				}

				response.write(error);
			} finally {
				response.end();
			}
		}
	);

	app = newApp;
	await newApp.listen(TGF_PORT);

	vscode.window.showInformationMessage(`REST API now running on port ${newApp.port}`);
}

export async function deactivate() {
	// close server
	await app?.close();
}
