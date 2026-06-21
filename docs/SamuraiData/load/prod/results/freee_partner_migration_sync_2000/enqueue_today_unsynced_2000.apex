List<Id> jobIds = FreeePartnerMigrationSyncService.enqueueTodayUnsynced(2000);
System.debug('MIGRATION_PARTNER_SYNC_ENQUEUED todayUnsynced accountsMax=2000 jobs=' + jobIds.size() + ' jobIds=' + jobIds);
