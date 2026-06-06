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
  subtype?: string;
  text?: string;
  result?: string;
  timestamp_ms?: number;
  model_call_id?: string;
  usage?: {
    inputTokens?: number;
    outputTokens?: number;
    reasoningTokens?: number;
    cacheReadTokens?: number;
    cacheWriteTokens?: number;
  };
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
