ContractClassBackfillService.Result result =
    ContractClassBackfillService.dryRun();
System.debug(
    LoggingLevel.ERROR,
    'CONTRACT_CLASSIFICATION_DRY_RUN=' + JSON.serialize(result)
);
