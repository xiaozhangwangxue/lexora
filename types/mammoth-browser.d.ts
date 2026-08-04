declare module "mammoth/mammoth.browser" {
  export type Input = { arrayBuffer: ArrayBuffer };
  export type Result = { value: string; messages: unknown[] };

  export function extractRawText(input: Input): Promise<Result>;
  export function convertToHtml(input: Input): Promise<Result>;

  const mammoth: {
    extractRawText: typeof extractRawText;
    convertToHtml: typeof convertToHtml;
  };

  export default mammoth;
}
