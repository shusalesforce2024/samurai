ContractClassBackfillService.Result result = ContractClassBackfillService.dryRun();
System.debug(LoggingLevel.INFO, JSON.serializePretty(result));
