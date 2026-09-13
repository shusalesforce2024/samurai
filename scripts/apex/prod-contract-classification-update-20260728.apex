ContractClassBackfillService.Result result =
    ContractClassBackfillService.executeUpdate();
System.debug(
    LoggingLevel.ERROR,
    'CONTRACT_CLASSIFICATION_UPDATE=' + JSON.serialize(result)
);
