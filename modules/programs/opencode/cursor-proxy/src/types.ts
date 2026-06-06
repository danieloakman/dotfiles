export type ContentPart = {
  type: string;
  text?: string;
  mime?: string;
  mediaType?: string;
  mimeType?: string;
  data?: string;
  url?: string;
  uri?: string;
  path?: string;
  filename?: string;
  image_url?: { url: string };
  image?: { url?: string; data?: string; media_type?: string };
};

export type ChatMessage = {
  role?: string;
  content?: string | ContentPart[];
  tool_calls?: Array<{
    id?: string;
    function?: { name?: string; arguments?: string };
  }>;
  tool_call_id?: string;
};

export type StreamEvent = {
  type?: string;
  result?: string;
  timestamp_ms?: number;
  usage?: { inputTokens?: number; outputTokens?: number };
  message?: { content?: ContentPart[] };
};

export type OpenCodeConfig = {
  provider?: Record<
    string,
    {
      name?: string;
      npm?: string;
      options?: Record<string, unknown>;
      models?: Record<string, unknown>;
    }
  >;
};
