/********************************************************************************************************
 * This file is part of the Apex Validation Rules project, released under the MIT License.              *
 * See LICENSE file or go to https://github.com/jongpie/RecordValidationRules for full license details. *
 *******************************************************************************************************/

public without sharing class RecordValidator {
    private static final Map<Schema.SObjectType, List<RecordValidationRule__mdt>> CACHED_RULES_BY_SOBJECT_TYPE = new Map<Schema.SObjectType, List<RecordValidationRule__mdt>>();

    private final List<String> ruleDeveloperNames = new List<String>();
    private final Map<String, RecordValidationRule__mdt> rulesByDeveloperName = new Map<String, RecordValidationRule__mdt>();
    private final Map<String, List<RecordValidationRuleCondition__mdt>> conditionsByRuleDeveloperName = new Map<String, List<RecordValidationRuleCondition__mdt>>();

    private List<SObject> records;
    private Schema.SObjectType sobjectType;
    private Boolean rulesProvided = false;

    public RecordValidator(SObject record) {
        this(new List<SObject>{ record });
    }

    public RecordValidator(List<SObject> records) {
        this.records = records;
        this.sobjectType = records.get(0).getSObjectType();
    }

    public List<ValidationRuleResult> validate() {
        return this.validate(true);
    }

    public List<ValidationRuleResult> validate(Boolean shouldThrowException) {
        if (this.ruleDeveloperNames.isEmpty() == true && rulesProvided == false) {
            this.loadConfiguredRules(this.sobjectType);
        }

        // If there aren't any rules loaded or provided, then something isn't right
        if (shouldThrowException == true && this.ruleDeveloperNames.isEmpty() == true) {
            throw new RecordValidatorException('No rules provided or configured, cannot validate');
        }

        List<ValidationRuleResult> results = new List<ValidationRuleResult>();
        for (SObject record : this.records) {
            // record.recalculateFormulas();
            for (String ruleDeveloperName : this.ruleDeveloperNames) {
                RecordValidationRule__mdt rule = this.rulesByDeveloperName.get(ruleDeveloperName);
                List<RecordValidationRuleCondition__mdt> ruleConditions = this.conditionsByRuleDeveloperName.get(rule.DeveloperName);
                ValidationRuleResult ruleResult = new ValidationRuleResult(record, rule, ruleConditions);

                if (shouldThrowException == true && ruleResult.hasError == true) {
                    throw new RecordValidatorException(ruleResult.errorMessage);
                }

                results.add(ruleResult);
            }
        }
        return results;
    }

    // Private testVisible methods for mocking
    @testVisible
    private RecordValidator setRule(RecordValidationRule__mdt rule, List<RecordValidationRuleCondition__mdt> conditions) {
        this.ruleDeveloperNames.add(rule.DeveloperName);
        this.rulesByDeveloperName.put(rule.DeveloperName, rule);
        this.conditionsByRuleDeveloperName.put(rule.DeveloperName, conditions);
        return this;
    }

    // Private methods
    private void loadConfiguredRules(Schema.SObjectType sobjectType) {
        if (CACHED_RULES_BY_SOBJECT_TYPE.containsKey(sobjectType)) {
            return;
        }

        List<RecordValidationRule__mdt> configuredRules = [
            SELECT
                DeveloperName,
                SObjectType__c,
                ConditionLogicType__c,
                CustomConditionLogic__c,
                ErrorMessage__c,
                (SELECT FieldPath__c, Operator__c, ValueType__c, Value__c FROM RecordValidationRuleConditions__r ORDER BY SortOrder__c),
                (SELECT Language__c, ErrorMessage__c FROM RecordValidationRuleTranslations__r)
            FROM RecordValidationRule__mdt
            WHERE SObjectType__c = :String.valueOf(this.sobjectType) AND IsActive__c = TRUE
        ];

        // Add to the current instance's cache
        for (RecordValidationRule__mdt rule : configuredRules) {
            this.setRule(rule, rule.RecordValidationRuleConditions__r);
        }
        // Add to the static cache
        CACHED_RULES_BY_SOBJECT_TYPE.put(sobjectType, configuredRules);
    }

    public class RecordValidatorException extends Exception {
    }

    public class ValidationRuleResult {
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
        // public Id recordId {
        //     get {
        //         return this.record.Id;
        //     }
        //     private set;
        // }

        public SObject record;
        public RecordValidationRule__mdt rule;
        private List<RecordValidationRuleCondition__mdt> ruleConditions;

        public ValidationRuleResult(SObject record, RecordValidationRule__mdt rule, List<RecordValidationRuleCondition__mdt> ruleConditions) {
            this.record = record;
            this.rule = rule;
            this.ruleConditions = ruleConditions;

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
            if (this.rule.RecordValidationRuleTranslations__r.isEmpty() == true) {
                return this.rule.ErrorMessage__c;
            }

            for (RecordValidationRuleTranslation__mdt translation : this.rule.RecordValidationRuleTranslations__r) {
                if (translation.Language__c == UserInfo.getLanguage()) {
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

            this.hasError = this.getHasError();
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

        public Boolean getHasError() {
            if (this.ruleCondition.ValueType__c == 'RegEx') {
                return this.getHasRegExError();
            }

            Schema.SObjectField field = new FieldPath(this.sobjectApiName, this.ruleCondition.FieldPath__c).getField();

            Object recordFieldValue = this.getFieldValue();
            Object comparisonValue = this.getComparisonValue();

            switch on field.getDescribe().getType() {
                when Boolean {
                    return this.compareBoolean(Boolean.valueOf(recordFieldValue), Boolean.valueOf(comparisonValue));
                }
                when Currency, Double, Integer, Percent {
                    return this.compareDouble(Double.valueOf(recordFieldValue), Double.valueOf(comparisonValue));
                }
                when Date {
                    Date recordFieldDate = this.getAsDate(recordFieldValue);
                    Date comparisonDate = this.getAsDate(comparisonValue);
                    return this.compareDate(recordFieldDate, comparisonDate);
                }
                when Datetime {
                    Datetime recordFieldDatetime = this.getAsDatetime(recordFieldValue);
                    Datetime comparisonDatetime = this.getAsDatetime(comparisonValue);
                    return this.compareDatetime(recordFieldDatetime, comparisonDatetime);
                }
                when Email, Id, MultiPicklist, Phone, Picklist, Reference, String, Combobox, TextArea, Url {
                    return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue));
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

        private Boolean compareDouble(Double recordFieldValue, Double comparisonValue) {
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
                    throw new RecordValidatorException('Unsupported operator for Double: ' + this.ruleCondition.Operator__c);
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
                when 'CONTAINS' {
                    return recordFieldValue.contains(comparisonValue);
                }
                when else {
                    throw new RecordValidatorException('Unsupported operator for String: ' + this.ruleCondition.Operator__c);
                }
            }
        }

        private Date getAsDate(Object dateValue) {
            String dateString;
            if (dateValue == null) {
                return null;
            } else if (dateValue instanceof String) {
                dateString = (String) dateValue;
            } else {
                dateString = JSON.serialize(dateValue);
            }
            return (Date) JSON.deserialize(dateString, Date.class);
        }

        private Datetime getAsDatetime(Object datetimeValue) {
            String datetimeString;
            if (datetimeValue == null) {
                return null;
            } else if (datetimeValue instanceof String) {
                datetimeString = (String) datetimeValue;
            } else {
                datetimeString = JSON.serialize(datetimeValue);
            }
            return (Datetime) JSON.deserialize(datetimeString, Datetime.class);
        }
    }

    //https://salesforce.stackexchange.com/questions/113300/boolean-evaluation-in-apex/113308
    public class BooleanExpression {
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
