export type FileType = "jsonc" | "yaml";

/**
 * Reads a file as text
 */
export function readFileAsText(file: File): Promise<string> {
	return new Promise((resolve, reject) => {
		const reader = new FileReader();
		reader.onload = () => resolve(reader.result as string);
		reader.onerror = () => reject(new Error("Failed to read file"));
		reader.readAsText(file);
	});
}

/**
 * Determines file type from extension
 * .json / .jsonc -> "jsonc"
 * .yaml -> "yaml" (.yml is not supported)
 */
export function getFileType(filename: string): FileType | null {
	const lower = filename.toLowerCase();

	if (lower.endsWith(".yaml")) {
		return "yaml";
	}

	if (lower.endsWith(".jsonc") || lower.endsWith(".json")) {
		return "jsonc";
	}

	return null;
}

/**
 * Downloads content as a file
 */
export function downloadFile(
	content: string,
	filename: string,
	mimeType: string,
): void {
	const blob = new Blob([content], { type: mimeType });
	const url = URL.createObjectURL(blob);
	const a = document.createElement("a");
	a.href = url;
	a.download = filename;
	document.body.appendChild(a);
	a.click();
	document.body.removeChild(a);
	URL.revokeObjectURL(url);
}

/**
 * Generates a filename with timestamp
 */
export function generateFilename(base: string, ext: string): string {
	const now = new Date();
	const timestamp = now
		.toISOString()
		.replace(/[:.]/g, "-")
		.slice(0, -5);
	return `${base}-${timestamp}${ext}`;
}
