/********************************************************************************************************
 * This file is part of the Apex Validation Rules project, released under the MIT License.              *
 * See LICENSE file or go to https://github.com/jongpie/RecordValidationRules for full license details. *
 *******************************************************************************************************/

@isTest
private class RecordValidatorTest {
    static RecordValidationRule__mdt createMockRule() {
        return new RecordValidationRule__mdt(
            ConditionLogicType__c = 'AND',
            CustomConditionLogic__c = null,
            ErrorMessage__c = 'Whoops, an error occurred',
            IsActive__c = true
        );
    }

    static RecordValidationRuleCondition__mdt createMockRuleCondition(String fieldPath, String operator, String valueType, Object value) {
        String valueString = value instanceof String ? (String) value : JSON.serialize(value);
        return new RecordValidationRuleCondition__mdt(
            FieldPath__c = fieldPath,
            Operator__c = operator,
            SortOrder__c = null,
            Value__c = valueString,
            ValueType__c = valueType
        );
    }

    // Simpler tests - each test is for 1 field with a different data type
    @isTest
    static void validateForRuleWithBooleanFieldAndAllOperators() {
        String fieldPath = 'IsActive';
        User record = new User(IsActive = true);
        Map<String, Boolean> operatorToValue = new Map<String, Boolean>{ 'EQUAL_TO' => true, 'NOT_EQUAL_TO' => false };
        for (String operator : operatorToValue.keySet()) {
            Boolean value = operatorToValue.get(operator);

            RecordValidationRule__mdt rule = createMockRule();
            RecordValidationRuleCondition__mdt condition = createMockRuleCondition(fieldPath, operator, 'Value', value);
            List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{ condition };

            RecordValidator validator = new RecordValidator(record).setRule(rule, conditions);
            List<RecordValidator.ValidationRuleResult> results = validator.validate(false);
            System.assertEquals(1, results.size(), 'Expected 1 validation rule result: ' + results);

            RecordValidator.ValidationRuleResult result = results.get(0);
            System.assertEquals(true, result.hasError, result);
            System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

            try {
                validator.validate();
                System.assert(false, 'Exception expected on line above');
            } catch (RecordValidator.RecordValidatorException ex) {
                System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
            }
        }
    }

    @isTest
    static void validateForRuleWithDateFieldAndAllOperators() {
        String fieldPath = 'CloseDate';
        Date opportunityCloseDate = System.today();
        Opportunity record = new Opportunity(CloseDate = opportunityCloseDate);

        Map<String, Date> operatorToValue = new Map<String, Date>{
            'EQUAL_TO' => opportunityCloseDate,
            'NOT_EQUAL_TO' => opportunityCloseDate.addDays(10),
            'LESS_THAN' => opportunityCloseDate.addDays(10),
            'LESS_THAN_OR_EQUAL_TO' => opportunityCloseDate.addDays(10),
            'GREATER_THAN' => opportunityCloseDate.addDays(-10),
            'GREATER_THAN_OR_EQUAL_TO' => opportunityCloseDate.addDays(-10)
        };
        for (String operator : operatorToValue.keySet()) {
            Date value = operatorToValue.get(operator);

            RecordValidationRule__mdt rule = createMockRule();
            RecordValidationRuleCondition__mdt condition = createMockRuleCondition(fieldPath, operator, 'Value', value);
            List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{ condition };

            RecordValidator validator = new RecordValidator(record).setRule(rule, conditions);
            List<RecordValidator.ValidationRuleResult> results = validator.validate(false);
            System.assertEquals(1, results.size(), 'Expected 1 validation rule result: ' + results);

            RecordValidator.ValidationRuleResult result = results.get(0);
            System.assertEquals(true, result.hasError, result);
            System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

            try {
                validator.validate();
                System.assert(false, 'Exception expected on line above');
            } catch (RecordValidator.RecordValidatorException ex) {
                System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
            }
        }
    }

    @isTest
    static void validateForRuleWithDatetimeFieldAndAllOperators() {
        String fieldPath = 'ActivityDatetime';
        Datetime eventActivityDatetime = System.now().addDays(-3);
        Event record = new Event(ActivityDatetime = eventActivityDatetime);

        Map<String, Datetime> operatorToValue = new Map<String, Datetime>{
            'EQUAL_TO' => eventActivityDatetime,
            'NOT_EQUAL_TO' => eventActivityDatetime.addDays(10),
            'LESS_THAN' => eventActivityDatetime.addDays(10),
            'LESS_THAN_OR_EQUAL_TO' => eventActivityDatetime.addDays(10),
            'GREATER_THAN' => eventActivityDatetime.addDays(-10),
            'GREATER_THAN_OR_EQUAL_TO' => eventActivityDatetime.addDays(-10)
        };
        for (String operator : operatorToValue.keySet()) {
            Datetime value = operatorToValue.get(operator);

            RecordValidationRule__mdt rule = createMockRule();
            RecordValidationRuleCondition__mdt condition = createMockRuleCondition(fieldPath, operator, 'Value', value);
            List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{ condition };

            RecordValidator validator = new RecordValidator(record).setRule(rule, conditions);
            List<RecordValidator.ValidationRuleResult> results = validator.validate(false);
            System.assertEquals(1, results.size(), 'Expected 1 validation rule result: ' + results);

            RecordValidator.ValidationRuleResult result = results.get(0);
            System.assertEquals(true, result.hasError, result);
            System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

            try {
                validator.validate();
                System.assert(false, 'Exception expected on line above');
            } catch (RecordValidator.RecordValidatorException ex) {
                System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
            }
        }
    }

    @isTest
    static void validateForRuleWithDoubleFieldAndAllOperators() {
        String fieldPath = 'AnnualRevenue';
        Double accountAnnualRevenue = 123000;
        Account record = new Account(Name = 'Test account');
        record.AnnualRevenue = accountAnnualRevenue;

        Map<String, Double> operatorToValue = new Map<String, Double>{
            'EQUAL_TO' => accountAnnualRevenue,
            'NOT_EQUAL_TO' => accountAnnualRevenue + 10,
            'LESS_THAN' => accountAnnualRevenue + 10,
            'LESS_THAN_OR_EQUAL_TO' => accountAnnualRevenue + 10,
            'GREATER_THAN' => accountAnnualRevenue - 10,
            'GREATER_THAN_OR_EQUAL_TO' => accountAnnualRevenue - 10
        };
        for (String operator : operatorToValue.keySet()) {
            Double value = operatorToValue.get(operator);

            RecordValidationRule__mdt rule = createMockRule();
            RecordValidationRuleCondition__mdt condition = createMockRuleCondition(fieldPath, operator, 'Value', value);
            List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{ condition };

            RecordValidator validator = new RecordValidator(record).setRule(rule, conditions);
            List<RecordValidator.ValidationRuleResult> results = validator.validate(false);
            System.assertEquals(1, results.size(), 'Expected 1 validation rule result: ' + results);

            RecordValidator.ValidationRuleResult result = results.get(0);
            System.assertEquals(true, result.hasError, result);
            System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

            try {
                validator.validate();
                System.assert(false, 'Exception expected on line above');
            } catch (RecordValidator.RecordValidatorException ex) {
                System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
            }
        }
    }

    @isTest
    static void validateForRuleWithStringFieldAndAllOperators() {
        String fieldPath = 'Name';
        String accountName = 'Some account';
        Account record = new Account(Name = 'Test account');
        record.Name = accountName;

        Map<String, String> operatorToValue = new Map<String, String>{
            'EQUAL_TO' => accountName,
            'NOT_EQUAL_TO' => 'something else',
            'CONTAINS' => accountName.left(3)
        };
        for (String operator : operatorToValue.keySet()) {
            String value = operatorToValue.get(operator);

            RecordValidationRule__mdt rule = createMockRule();
            RecordValidationRuleCondition__mdt condition = createMockRuleCondition(fieldPath, operator, 'Value', value);
            List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{ condition };

            RecordValidator validator = new RecordValidator(record).setRule(rule, conditions);
            List<RecordValidator.ValidationRuleResult> results = validator.validate(false);
            System.assertEquals(1, results.size(), 'Expected 1 validation rule result: ' + results);

            RecordValidator.ValidationRuleResult result = results.get(0);
            System.assertEquals(true, result.hasError, result);
            System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

            try {
                validator.validate();
                System.assert(false, 'Exception expected on line above');
            } catch (RecordValidator.RecordValidatorException ex) {
                System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
            }
        }
    }

    // More complex tests
    @isTest
    static void validateForRuleWithOneBooleanFieldPathCondition() {
        Boolean managerIsActive = false;
        User manager = new User(IsActive = managerIsActive);
        User user = new User(Id = UserInfo.getUserId(), Manager = manager);

        RecordValidationRule__mdt rule = createMockRule();
        RecordValidationRuleCondition__mdt condition = createMockRuleCondition('Manager.IsActive', 'EQUAL_TO', 'Value', managerIsActive);
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{ condition };

        RecordValidator validator = new RecordValidator(user).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.validate(false);
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

        try {
            validator.validate();
            System.assert(false, 'Exception expected on line above');
        } catch (RecordValidator.RecordValidatorException ex) {
            System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
        }
    }

    @isTest
    static void validateForRuleWithOneRegexFieldCondition() {
        String accountName = '123';
        Account account = new Account(Name = 'Test account');
        account.Name = accountName;

        RecordValidationRule__mdt rule = createMockRule();
        RecordValidationRuleCondition__mdt condition = createMockRuleCondition('Name', '^[0-9]+$', 'RegEx', accountName);
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{ condition };

        RecordValidator validator = new RecordValidator(account).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.validate(false);
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

        try {
            validator.validate();
            System.assert(false, 'Exception expected on line above');
        } catch (RecordValidator.RecordValidatorException ex) {
            System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
        }
    }

    @isTest
    static void validateForRuleWithAndConditions() {
        String accountName = 'Some account';
        Integer accountAnnualRevenue = 123000;
        Account account = new Account(Name = 'Test account');
        account.Name = accountName;
        account.AnnualRevenue = accountAnnualRevenue;

        RecordValidationRule__mdt rule = createMockRule();
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{
            createMockRuleCondition('Name', 'EQUAL_TO', 'Value', accountName),
            createMockRuleCondition('AnnualRevenue', 'GREATER_THAN_OR_EQUAL_TO', 'Value', accountAnnualRevenue)
        };

        RecordValidator validator = new RecordValidator(account).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.validate(false);
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

        try {
            validator.validate();
            System.assert(false, 'Exception expected on line above');
        } catch (RecordValidator.RecordValidatorException ex) {
            System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
        }
    }

    @isTest
    static void validateForRuleWithOrConditions() {
        String accountName1 = 'Some account';
        String accountName2 = 'another account';
        Account account = new Account(Name = 'Test account');
        account.Name = accountName1;

        RecordValidationRule__mdt rule = createMockRule();
        rule.ConditionLogicType__c = 'OR';
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{
            createMockRuleCondition('Name', 'EQUAL_TO', 'Value', accountName1),
            createMockRuleCondition('Name', 'EQUAL_TO', 'Value', accountName2)
        };

        RecordValidator validator = new RecordValidator(account).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.validate(false);
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

        try {
            validator.validate();
            System.assert(false, 'Exception expected on line above');
        } catch (RecordValidator.RecordValidatorException ex) {
            System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
        }
    }

    @isTest
    static void validateForRuleWithCustomConditions() {
        String accountName1 = 'Some account';
        String accountName2 = 'another account';
        Integer accountAnnualRevenue = 123000;
        Account account = new Account(Name = 'Test account');
        account.Name = accountName1;
        account.AnnualRevenue = accountAnnualRevenue;

        RecordValidationRule__mdt rule = createMockRule();
        rule.ConditionLogicType__c = 'Custom';
        rule.CustomConditionLogic__c = '((1 OR 2) AND 3)';
        List<RecordValidationRuleCondition__mdt> conditions = new List<RecordValidationRuleCondition__mdt>{
            createMockRuleCondition('Name', 'EQUAL_TO', 'Value', accountName1),
            createMockRuleCondition('Name', 'EQUAL_TO', 'Value', accountName2),
            createMockRuleCondition('AnnualRevenue', 'GREATER_THAN_OR_EQUAL_TO', 'Value', accountAnnualRevenue)
        };

        RecordValidator validator = new RecordValidator(account).setRule(rule, conditions);
        List<RecordValidator.ValidationRuleResult> results = validator.validate(false);
        System.assertEquals(1, results.size(), 'Expected 1 validation rule result');

        RecordValidator.ValidationRuleResult result = results.get(0);
        System.assertEquals(true, result.hasError, result);
        System.assertEquals(rule.ErrorMessage__c, result.errorMessage, result);

        try {
            validator.validate();
            System.assert(false, 'Exception expected on line above');
        } catch (RecordValidator.RecordValidatorException ex) {
            System.assert(ex.getMessage().contains(rule.ErrorMessage__c), ex);
        }
    }
}
