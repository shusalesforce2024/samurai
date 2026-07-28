ContractClassBackfillService.Result result = ContractClassBackfillService.executeUpdate();
System.debug(LoggingLevel.INFO, JSON.serializePretty(result));
