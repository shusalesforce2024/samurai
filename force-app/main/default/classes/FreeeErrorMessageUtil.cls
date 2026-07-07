public with sharing class FreeeErrorMessageUtil {
    public static String buildDetailedFreeeError(String responseBody) {
        String summary = summarizeFreeeError(responseBody);

        if (String.isBlank(responseBody)) {
            return summary;
        }
        if (summary == responseBody) {
            return responseBody;
        }

        return summary + '\n\nRaw response:\n' + responseBody;
    }

    public static String summarizeFreeeError(String responseBody) {
        if (String.isBlank(responseBody)) {
            return 'freee からエラー詳細を取得できませんでした。';
        }

        try {
            Object parsed = JSON.deserializeUntyped(responseBody);
            if (!(parsed instanceof Map<String, Object>)) {
                return responseBody;
            }

            Map<String, Object> bodyMap = (Map<String, Object>) parsed;
            String rateLimitMessage = buildRateLimitMessage(bodyMap);
            if (String.isNotBlank(rateLimitMessage)) {
                return rateLimitMessage;
            }

            if (bodyMap.containsKey('message') && bodyMap.get('message') != null) {
                return String.valueOf(bodyMap.get('message'));
            }

            if (bodyMap.containsKey('errors') && bodyMap.get('errors') instanceof List<Object>) {
                List<Object> errors = (List<Object>) bodyMap.get('errors');
                List<String> messages = new List<String>();

                for (Object errorItem : errors) {
                    if (errorItem instanceof Map<String, Object>) {
                        Map<String, Object> errorMap = (Map<String, Object>) errorItem;
                        if (errorMap.containsKey('messages')
                            && errorMap.get('messages') instanceof List<Object>
                        ) {
                            List<Object> errorMessages = (List<Object>) errorMap.get('messages');
                            for (Object errorMessage : errorMessages) {
                                if (errorMessage != null) {
                                    messages.add(String.valueOf(errorMessage));
                                }
                            }
                        } else if (errorMap.containsKey('message')
                            && errorMap.get('message') != null
                        ) {
                            messages.add(String.valueOf(errorMap.get('message')));
                        } else {
                            messages.add(JSON.serialize(errorMap));
                        }
                    } else if (errorItem != null) {
                        messages.add(String.valueOf(errorItem));
                    }
                }

                if (!messages.isEmpty()) {
                    return String.join(messages, ' / ');
                }
            }
        } catch (Exception e) {
            System.debug('freee エラーレスポンスの解析に失敗しました: ' + e.getMessage());
        }

        return responseBody;
    }

    private static String buildRateLimitMessage(Map<String, Object> bodyMap) {
        String statusCode = stringValue(bodyMap.get('status_code'));
        if (statusCode != '429') {
            return null;
        }

        Map<String, Object> meta = new Map<String, Object>();
        if (bodyMap.get('meta') instanceof Map<String, Object>) {
            meta = (Map<String, Object>) bodyMap.get('meta');
        }

        String limitValue = stringValue(meta.get('limit'));
        String periodValue = stringValue(meta.get('period'));
        String remainingValue = stringValue(meta.get('remaining'));
        String resetValue = stringValue(meta.get('reset'));
        String periodLabel = toPeriodLabel(periodValue);

        List<String> parts = new List<String>{
            'freee APIの利用上限に達しました。'
        };

        if (String.isNotBlank(limitValue)) {
            parts.add(periodLabel + 'の上限 ' + limitValue + '回を使い切っています。');
        }
        if (String.isNotBlank(remainingValue)) {
            parts.add('残り回数: ' + remainingValue + '回。');
        }
        if (String.isNotBlank(resetValue)) {
            parts.add('リセット予定時刻: ' + resetValue + '。');
        }
        parts.add('リセット後に再実行してください。');

        return String.join(parts, ' ');
    }

    private static String toPeriodLabel(String periodValue) {
        if (periodValue == '60') {
            return '1分あたり';
        }
        if (periodValue == '3600') {
            return '1時間あたり';
        }
        if (periodValue == '86400') {
            return '1日あたり';
        }
        if (String.isNotBlank(periodValue)) {
            return periodValue + '秒あたり';
        }
        return 'freee API';
    }

    private static String stringValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }
}
