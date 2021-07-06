/********************************************************************************************************
 * This file is part of the Apex Validation Rules project, released under the MIT License.              *
 * See LICENSE file or go to https://github.com/jongpie/RecordValidationRules for full license details. *
 *******************************************************************************************************/

public without sharing class RecordValidator {
    private static final Map<Schema.SObjectType, List<RecordValidationRule__mdt>> QUERIED_RULES_BY_SOBJECT_TYPE = new Map<Schema.SObjectType, List<RecordValidationRule__mdt>>();

    private final Map<String, RecordValidationRule__mdt> rulesByDeveloperName = new Map<String, RecordValidationRule__mdt>();
    private final Map<String, List<RecordValidationRuleCondition__mdt>> conditionsByRuleDeveloperName = new Map<String, List<RecordValidationRuleCondition__mdt>>();
    private final Map<String, List<RecordValidationRuleTranslation__mdt>> translationsByRuleDeveloperName = new Map<String, List<RecordValidationRuleTranslation__mdt>>();

    private List<SObject> records;
    private Schema.SObjectType sobjectType;
    private Boolean rulesProvided = false;
    private String languageLocaleKey = UserInfo.getLanguage();

    public RecordValidator(SObject record) {
        this(new List<SObject>{ record });
    }

    public RecordValidator(List<SObject> records) {
        this.records = records;
        this.sobjectType = records.get(0).getSObjectType();
    }

    public RecordValidator setRule(RecordValidationRule__mdt rule, List<RecordValidationRuleCondition__mdt> conditions) {
        return this.setRule(rule, conditions, null);
    }

    public RecordValidator setRule(
        RecordValidationRule__mdt rule,
        List<RecordValidationRuleCondition__mdt> conditions,
        List<RecordValidationRuleTranslation__mdt> translations
    ) {
        this.rulesByDeveloperName.put(rule.DeveloperName, rule);
        this.conditionsByRuleDeveloperName.put(rule.DeveloperName, conditions);
        this.translationsByRuleDeveloperName.put(rule.DeveloperName, translations);
        this.rulesProvided = true;
        return this;
    }

    public RecordValidator setLanguageLocale(String languageLocaleKey) {
        this.languageLocaleKey = languageLocaleKey;
        return this;
    }

    public List<ValidationRuleResult> validate() {
        return this.validate(true);
    }

    public List<ValidationRuleResult> validate(Boolean shouldThrowException) {
        if (this.rulesByDeveloperName.isEmpty() == true && rulesProvided == false) {
            this.loadConfiguredRules();
        }

        // If there aren't any rules loaded or provided, then something isn't right
        if (shouldThrowException == true && this.rulesByDeveloperName.isEmpty() == true) {
            throw new RecordValidatorException('No rules provided or configured, cannot validate');
        }

        List<ValidationRuleResult> results = new List<ValidationRuleResult>();
        for (SObject record : this.records) {
            for (String ruleDeveloperName : this.rulesByDeveloperName.keySet()) {
                RecordValidationRule__mdt rule = this.rulesByDeveloperName.get(ruleDeveloperName);
                List<RecordValidationRuleCondition__mdt> ruleConditions = this.conditionsByRuleDeveloperName.get(rule.DeveloperName);
                List<RecordValidationRuleTranslation__mdt> ruleTranslations = this.translationsByRuleDeveloperName.get(rule.DeveloperName);
                ValidationRuleResult ruleResult = new ValidationRuleResult(record, rule, ruleConditions, this.languageLocaleKey, ruleTranslations);

                if (shouldThrowException == true && ruleResult.hasError == true) {
                    throw new RecordValidatorException(ruleResult.errorMessage);
                }

                results.add(ruleResult);
            }
        }
        return results;
    }

    // Private methods
    private void loadConfiguredRules() {
        if (QUERIED_RULES_BY_SOBJECT_TYPE.containsKey(this.sobjectType) == false) {
            List<RecordValidationRule__mdt> configuredRules = [
                SELECT
                    DeveloperName,
                    SObjectType__c,
                    ConditionLogicType__c,
                    CustomConditionLogic__c,
                    ErrorMessage__c,
                    (
                        SELECT FieldPath__c, Operator__c, ValueType__c, Value__c
                        FROM RecordValidationRuleConditions__r
                        ORDER BY SortOrder__c NULLS LAST, DeveloperName
                    ),
                    (SELECT LanguageLocaleKey__c, ErrorMessage__c FROM RecordValidationRuleTranslations__r)
                FROM RecordValidationRule__mdt
                WHERE SObjectType__c = :String.valueOf(this.sobjectType) AND IsActive__c = TRUE
            ];
            // Add to the static cache
            QUERIED_RULES_BY_SOBJECT_TYPE.put(this.sobjectType, configuredRules);
        }

        // Add to the current instance's cache
        for (RecordValidationRule__mdt rule : QUERIED_RULES_BY_SOBJECT_TYPE.get(this.sobjectType)) {
            this.setRule(rule, rule.RecordValidationRuleConditions__r, rule.RecordValidationRuleTranslations__r);
        }
    }

    public class RecordValidatorException extends Exception {
    }

    public class ValidationRuleResult {
        public SObject record { get; private set; }
        public List<String> conditions { get; private set; }
        public String conditionsLogic { get; private set; }
        public String conditionsLogicType { get; private set; }
        public String errorMessage { get; private set; }
        public Boolean hasError {
            get {
                return String.isNotBlank(this.errorMessage);
            }
            private set;
        }

        private RecordValidationRule__mdt rule;
        private List<RecordValidationRuleCondition__mdt> ruleConditions;
        private List<RecordValidationRuleTranslation__mdt> ruleTranslations;
        private String languageLocaleKey;

        public ValidationRuleResult(
            SObject record,
            RecordValidationRule__mdt rule,
            List<RecordValidationRuleCondition__mdt> ruleConditions,
            String languageLocaleKey,
            List<RecordValidationRuleTranslation__mdt> ruleTranslations
        ) {
            this.record = record;
            this.rule = rule;
            this.ruleConditions = ruleConditions;
            this.languageLocaleKey = languageLocaleKey;
            this.ruleTranslations = ruleTranslations;

            this.conditions = new List<String>();
            this.conditionsLogic = this.getRuleConditionsLogic();
            this.conditionsLogicType = rule.ConditionLogicType__c;

            this.process();
        }

        private void process() {
            List<String> booleanValues = new List<String>();
            for (RecordValidationRuleCondition__mdt ruleCondition : this.ruleConditions) {
                ValidationRuleConditionResult ruleConditionResult = new ValidationRuleConditionResult(this.record, ruleCondition);
                this.conditions.add(ruleConditionResult.getCondition());
                booleanValues.add(String.valueOf(ruleConditionResult.hasError));
            }

            String parsedConditionsLogic = String.format(this.getRuleConditionsLogic(), booleanValues);

            Boolean hasError = new BooleanExpression().evaluate(parsedConditionsLogic);
            if (hasError) {
                this.errorMessage = this.getErrorMessage();
            }
        }

        private String getErrorMessage() {
            if (String.isBlank(this.languageLocaleKey) || this.ruleTranslations == null || this.ruleTranslations.isEmpty() == true) {
                return this.rule.ErrorMessage__c;
            }

            for (RecordValidationRuleTranslation__mdt translation : this.ruleTranslations) {
                if (this.languageLocaleKey.toLowerCase() == translation.LanguageLocaleKey__c.toLowerCase()) {
                    return translation.ErrorMessage__c;
                }
            }

            return this.rule.ErrorMessage__c;
        }

        private String getRuleConditionsLogic() {
            String conditionsLogic = String.isBlank(this.rule.CustomConditionLogic__c) ? '' : this.rule.CustomConditionLogic__c;

            if (this.rule.ConditionLogicType__c != 'Custom') {
                List<String> standardLogicPieces = new List<String>();
                for (Integer i = 0; i < this.ruleConditions.size(); i++) {
                    standardLogicPieces.add(String.valueOf(i + 1));
                }
                conditionsLogic = '(' + String.join(standardLogicPieces, ' ' + this.rule.ConditionLogicType__c + ' ') + ')';
            }

            List<String> parsedCharacters = new List<String>();
            Boolean hasFoundNumbers = false;
            String foundNumberString = '';

            for (String character : conditionsLogic.split('')) {
                if (!character.isNumeric() && !hasFoundNumbers) {
                    parsedCharacters.add(character);
                } else if (!character.isNumeric() && hasFoundNumbers) {
                    hasFoundNumbers = false;
                    Integer foundNumber = Integer.valueOf(foundNumberString) - 1;
                    System.debug('foundNumber==' + foundNumber);

                    parsedCharacters.add('{' + foundNumber + '}');
                    foundNumberString = '';
                    parsedCharacters.add(character);
                } else if (character.isNumeric()) {
                    hasFoundNumbers = true;
                    foundNumberString += character;
                } else if (hasFoundNumbers && !character.isNumeric() && !String.isBlank(foundNumberString)) {
                    Integer foundNumber = Integer.valueOf(foundNumberString) - 1;
                    System.debug('foundNumber==' + foundNumber);

                    parsedCharacters.add('{' + foundNumber + '}');
                    foundNumberString = '';
                } else {
                    parsedCharacters.add(character);
                }
            }
            return String.join(parsedCharacters, '').toUpperCase();
        }
    }

    private class ValidationRuleConditionResult {
        private Boolean hasError;
        private SObject record;
        private RecordValidationRuleCondition__mdt ruleCondition;
        private String sobjectApiName;

        private ValidationRuleConditionResult(SObject record, RecordValidationRuleCondition__mdt ruleCondition) {
            this.record = record;
            this.ruleCondition = ruleCondition;
            this.sobjectApiName = this.record.getSObjectType().getDescribe().getName();

            this.hasError = this.hasError();
        }

        public String getCondition() {
            return this.ruleCondition.FieldPath__c +
                ' ' +
                this.ruleCondition.Operator__c +
                ' ' +
                this.getComparisonValue() +
                ' (' +
                this.ruleCondition.ValueType__c +
                ')';
        }

        public Boolean hasError() {
            if (this.ruleCondition.ValueType__c == 'RegEx') {
                return this.getHasRegExError();
            }

            Schema.SObjectField field = new FieldPath(this.sobjectApiName, this.ruleCondition.FieldPath__c).getField();

            Object recordFieldValue = this.getFieldValue();
            Object comparisonValue = this.getComparisonValue();

            switch on field.getDescribe().getType() {
                when Boolean {
                    return this.compareBoolean((Boolean) recordFieldValue, this.getAsBoolean(comparisonValue));
                }
                when Currency, Double, Integer, Percent {
                    return this.compareDecimal((Decimal) recordFieldValue, this.getAsDecimal(comparisonValue));
                }
                when Date {
                    return this.compareDate((Date) recordFieldValue, this.getAsDate(comparisonValue));
                }
                when Datetime {
                    return this.compareDatetime((Datetime) recordFieldValue, this.getAsDatetime(comparisonValue));
                }
                when Email, Id, MultiPicklist, Phone, Picklist, Reference, String, Combobox, TextArea, Url {
                    return this.compareString((String) recordFieldValue, String.valueOf(comparisonValue));
                }
                when else {
                    throw new RecordValidatorException('Could not process field path: ' + this.ruleCondition.FieldPath__c);
                }
            }
        }

        private Boolean getHasRegExError() {
            Pattern pattern = Pattern.compile(this.ruleCondition.Value__c);
            return pattern.matcher(String.valueOf(this.getFieldValue())).matches();
        }

        private Object getFieldValue() {
            return new FieldPath(this.sobjectApiName, this.ruleCondition.FieldPath__c).getValue(this.record);
        }

        private Object getComparisonValue() {
            switch on this.ruleCondition.ValueType__c {
                when 'Field' {
                    return new FieldPath(this.sobjectApiName, this.ruleCondition.Value__c).getValue(this.record);
                }
                when 'RegEx' {
                    return this.ruleCondition.Value__c;
                }
                when 'Value' {
                    return this.ruleCondition.Value__c;
                }
                when else {
                    throw new RecordValidatorException('Unknown Value Type, cannot parse comparison value');
                }
            }
        }

        // Helper methods for dealing with converting field values & strings
        // (stored in CMDT) to the appropriate data type
        private Boolean getAsBoolean(Object booleanValue) {
            if (booleanValue == null) {
                return null;
            } else if (booleanValue instanceof Boolean) {
                return (Boolean) booleanValue;
            } else {
                return Boolean.valueOf(booleanValue);
            }
        }

        private Date getAsDate(Object dateValue) {
            if (dateValue == null) {
                return null;
            } else if (dateValue instanceof Date) {
                return (Date) dateValue;
            } else {
                String dateString = (String) dateValue;
                return (Date) JSON.deserialize(dateString, Date.class);
            }
        }

        private Datetime getAsDatetime(Object datetimeValue) {
            if (datetimeValue == null) {
                return null;
            } else if (datetimeValue instanceof Datetime) {
                return (Datetime) datetimeValue;
            } else {
                String datetimeString = (String) datetimeValue;
                return (Datetime) JSON.deserialize(datetimeString, Datetime.class);
            }
        }

        private Decimal getAsDecimal(Object decimalValue) {
            if (decimalValue == null) {
                return null;
            } else if (decimalValue instanceof Decimal) {
                return (Decimal) decimalValue;
            } else {
                String decimalString = (String) decimalValue;
                return (Decimal) JSON.deserialize(decimalString, Decimal.class);
            }
        }

        // In Apex, you can't use comparison operators on instances of Object, so several private methods are used for each data type
        // Example of what you can't do in Apex:
        //          Object today = System.today();
        //          Object yesterday = System.today().addDays(-1);
        //          System.assert(today > yesterday); // This line cannot execute since it's comparing Object
        private Boolean compareBoolean(Boolean recordFieldValue, Boolean comparisonValue) {
            switch on this.ruleCondition.Operator__c {
                when 'EQUAL_TO' {
                    return recordFieldValue == comparisonValue;
                }
                when 'NOT_EQUAL_TO' {
                    return recordFieldValue != comparisonValue;
                }
                when else {
                    throw new RecordValidatorException('Unsupported operator for Boolean: ' + this.ruleCondition.Operator__c);
                }
            }
        }

        private Boolean compareDate(Date recordFieldValue, Date comparisonValue) {
            switch on this.ruleCondition.Operator__c {
                when 'EQUAL_TO' {
                    return recordFieldValue == comparisonValue;
                }
                when 'NOT_EQUAL_TO' {
                    return recordFieldValue != comparisonValue;
                }
                when 'LESS_THAN' {
                    return recordFieldValue < comparisonValue;
                }
                when 'LESS_THAN_OR_EQUAL_TO' {
                    return recordFieldValue <= comparisonValue;
                }
                when 'GREATER_THAN' {
                    return recordFieldValue > comparisonValue;
                }
                when 'GREATER_THAN_OR_EQUAL_TO' {
                    return recordFieldValue >= comparisonValue;
                }
                when else {
                    throw new RecordValidatorException('Unsupported operator for Date: ' + this.ruleCondition.Operator__c);
                }
            }
        }

        private Boolean compareDatetime(Datetime recordFieldValue, Datetime comparisonValue) {
            switch on this.ruleCondition.Operator__c {
                when 'EQUAL_TO' {
                    return recordFieldValue == comparisonValue;
                }
                when 'NOT_EQUAL_TO' {
                    return recordFieldValue != comparisonValue;
                }
                when 'LESS_THAN' {
                    return recordFieldValue < comparisonValue;
                }
                when 'LESS_THAN_OR_EQUAL_TO' {
                    return recordFieldValue <= comparisonValue;
                }
                when 'GREATER_THAN' {
                    return recordFieldValue > comparisonValue;
                }
                when 'GREATER_THAN_OR_EQUAL_TO' {
                    return recordFieldValue >= comparisonValue;
                }
                when else {
                    throw new RecordValidatorException('Unsupported operator for Datetime: ' + this.ruleCondition.Operator__c);
                }
            }
        }

        private Boolean compareDecimal(Decimal recordFieldValue, Decimal comparisonValue) {
            switch on this.ruleCondition.Operator__c {
                when 'EQUAL_TO' {
                    return recordFieldValue == comparisonValue;
                }
                when 'NOT_EQUAL_TO' {
                    return recordFieldValue != comparisonValue;
                }
                when 'LESS_THAN' {
                    return recordFieldValue < comparisonValue;
                }
                when 'LESS_THAN_OR_EQUAL_TO' {
                    return recordFieldValue <= comparisonValue;
                }
                when 'GREATER_THAN' {
                    return recordFieldValue > comparisonValue;
                }
                when 'GREATER_THAN_OR_EQUAL_TO' {
                    return recordFieldValue >= comparisonValue;
                }
                when else {
                    throw new RecordValidatorException('Unsupported operator for Decimal: ' + this.ruleCondition.Operator__c);
                }
            }
        }

        private Boolean compareString(String recordFieldValue, String comparisonValue) {
            switch on this.ruleCondition.Operator__c {
                when 'EQUAL_TO' {
                    return recordFieldValue == comparisonValue;
                }
                when 'NOT_EQUAL_TO' {
                    return recordFieldValue != comparisonValue;
                }
                when 'STARTS_WITH' {
                    return recordFieldValue.startsWith(comparisonValue);
                }
                when 'CONTAINS' {
                    return recordFieldValue.contains(comparisonValue);
                }
                when 'ENDS_WITH' {
                    return recordFieldValue.endsWith(comparisonValue);
                }
                when else {
                    throw new RecordValidatorException('Unsupported operator for String: ' + this.ruleCondition.Operator__c);
                }
            }
        }
    }

    // Credit goes to this StackExchange post for the original BooleanExpression class -
    // below is a modified version of the class
    // https://salesforce.stackexchange.com/questions/113300/boolean-evaluation-in-apex/113308
    private class BooleanExpression {
        public Boolean evaluate(String x) {
            x = simplify(x);

            if (isSimpleExpression(x)) {
                return Boolean.valueOf(x);
            }

            if (x.contains('&&')) {
                return andJoin(x.split('&&', 2)[0], x.split('&&', 2)[1]);
            }

            if (x.contains('||')) {
                String p1 = x.split('\\|\\|', 2)[0];
                String p2 = x.split('\\|\\|', 2)[1];

                return orJoin(p1, p2);
            }

            if (x.startsWith('!')) {
                return !evaluate(x.substring(1));
            }

            return Boolean.valueOf(x);
        }

        private Boolean orJoin(String x, String y) {
            return evaluate(x) || evaluate(y);
        }

        private Boolean andJoin(String x, String y) {
            return evaluate(x) && evaluate(y);
        }

        private Boolean isSimpleExpression(String x) {
            return x == 'true' || x == 'false';
        }

        private String simplify(String x) {
            x = x.trim();
            x = x.replace('AND', '&&');
            x = x.replace('OR', '||');
            while (x.contains('(') == true) {
                String sub = x.substringAfterLast('(').substringBefore(')');
                x = x.replace('(' + sub + ')', String.valueOf(evaluate(sub)));
            }
            return x;
        }
    }

    public class FieldPath {
        private List<Schema.SObjectField> fieldChain;
        private Schema.DescribeFieldResult fieldDescribe;
        private String fieldPath;
        private Schema.SObjectType sobjectType;

        public FieldPath(String sobjectApiName, String fieldPath) {
            Schema.SObjectType sobjectType = Schema.getGlobalDescribe().get(sobjectApiName);

            this.fieldChain = this.getFieldChain(sobjectType, fieldPath);
            this.fieldPath = fieldPath;

            this.fieldDescribe = this.getLastFieldDescribe();
        }

        public Schema.SObjectField getField() {
            return this.fieldChain[this.fieldChain.size() - 1];
        }

        public Object getValue(SObject record) {
            Schema.SObjectType parentSObjectType = this.sobjectType;
            SObject parentRecord = record;

            for (Schema.SObjectField field : this.fieldChain) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                String relationshipName = fieldDescribe.getRelationshipName();

                if (fieldDescribe.getSoapType() != Schema.SoapType.Id) {
                    return parentRecord.get(fieldDescribe.getName());
                } else {
                    parentSObjectType = fieldDescribe.getReferenceTo()[0];

                    SObject newParentRecord = parentRecord.getSObject(field);
                    if (newParentRecord == null) {
                        return null;
                    } else {
                        parentRecord = newParentRecord;
                    }
                }
            }

            return null;
        }

        private List<Schema.SObjectField> getFieldChain(Schema.SObjectType sobjectType, String fieldPath) {
            Schema.SObjectType currentSObjectType = sobjectType;

            List<Schema.SObjectField> fields = new List<Schema.SObjectField>();
            List<String> fieldPathPieces = fieldPath.split('\\.');
            Integer lastFieldIndex = fieldPathPieces.size() <= 1 ? 0 : fieldPathPieces.size() - 1;

            for (Integer i = 0; i < fieldPathPieces.size(); i++) {
                String fieldPathPiece = fieldPathPieces[i];

                String fieldApiName;
                if (i == lastFieldIndex) {
                    fieldApiName = fieldPathPiece;
                } else if (fieldPathPiece.endsWith('__r')) {
                    fieldApiName = fieldPathPiece.replace('__r', '__c');
                } else {
                    fieldApiName = fieldPathPiece + 'Id';
                }

                Schema.SObjectField field = currentSObjectType.getDescribe().fields.getMap().get(fieldApiName);

                // TODO add support for polymorphic fields
                if (i < lastFieldIndex) {
                    currentSObjectType = field.getDescribe().getReferenceTo()[0];
                }

                fields.add(field);
            }

            return fields;
        }

        private Schema.DescribeFieldResult getLastFieldDescribe() {
            Integer lastFieldIndex = this.fieldChain.size() - 1;
            return this.fieldChain[lastFieldIndex].getDescribe();
        }
    }
}
