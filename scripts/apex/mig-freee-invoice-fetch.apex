Integer targetYear = 2026;
Integer startMonth = 3;
Integer endMonth = 6;
Database.executeBatch(new Mig_FreeeInvoiceFetchBatch(targetYear, startMonth, endMonth), 1);
