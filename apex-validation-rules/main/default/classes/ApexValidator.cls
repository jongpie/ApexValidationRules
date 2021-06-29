/*****************************************************************************************************
 * This file is part of the Apex Validation Rules project, released under the MIT License.            *
 * See LICENSE file or go to https://github.com/jongpie/ApexValidationRules for full license details. *
 *****************************************************************************************************/
public without sharing class ApexValidator {
    // TODO re-add sorted list for rules based on SortOrder__c field
    private static final Map<String, ApexValidationRule__mdt> RULES_BY_DEVELOPER_NAME = new Map<String, ApexValidationRule__mdt>();
    private static final Map<String, List<ApexValidationRuleCondition__mdt>> CONDITIONS_BY_RULE_DEVELOPER_NAME = new Map<String, List<ApexValidationRuleCondition__mdt>>();

    private List<SObject> records;
    private Schema.SObjectType sobjectType;
    private Boolean rulesProvided = false;

    public ApexValidator(SObject record) {
        this(new List<SObject>{ record });
    }

    public ApexValidator(List<SObject> records) {
        this.records = records;
        this.sobjectType = records.get(0).getSObjectType();
    }

    public ApexValidator setRule(ApexValidationRule__mdt rule) {
        this.rulesProvided = true;
        return this.setRule(rule, rule.ApexValidationRuleConditions__r);
    }

    public ApexValidator setRule(ApexValidationRule__mdt rule, List<ApexValidationRuleCondition__mdt> conditions) {
        RULES_BY_DEVELOPER_NAME.put(rule.DeveloperName, rule);
        CONDITIONS_BY_RULE_DEVELOPER_NAME.put(rule.DeveloperName, conditions);
        return this;
    }

    public ApexValidator setRules(List<ApexValidationRule__mdt> rules) {
        for (ApexValidationRule__mdt rule : rules) {
            this.setRule(rule);
        }
        return this;
    }

    public List<ApexValidationRuleResult> getResults() {
        return this.validate(false);
    }

    public void validate() {
        this.validate(true);
    }

    private List<ApexValidationRuleCondition__mdt> getConditions(String ruleDeveloperName) {
        return CONDITIONS_BY_RULE_DEVELOPER_NAME.get(ruleDeveloperName);
    }

    private List<ApexValidationRuleResult> validate(Boolean shouldThrowException) {
        if (RULES_BY_DEVELOPER_NAME.isEmpty() == true && rulesProvided == false) {
            this.loadConfiguredRules();
        }

        // If there aren't any rules loaded or provided, then something isn't right
        if (shouldThrowException == true && RULES_BY_DEVELOPER_NAME.isEmpty() == true) {
            throw new ApexValidatorException('No rules provided or configured, cannot validate');
        }

        List<ApexValidationRuleResult> results = new List<ApexValidationRuleResult>();
        for (SObject record : this.records) {
            record.recalculateFormulas();
            for (ApexValidationRule__mdt rule : RULES_BY_DEVELOPER_NAME.values()) {
                List<ApexValidationRuleCondition__mdt> ruleConditions = CONDITIONS_BY_RULE_DEVELOPER_NAME.get(rule.DeveloperName);
                ApexValidationRuleResult ruleResult = new ApexValidationRuleResult(record, rule, ruleConditions);

                if (shouldThrowException == true && ruleResult.hasError == true) {
                    throw new ApexValidatorException(ruleResult.errorMessage);
                }

                results.add(ruleResult);
            }
        }
        return results;
    }

    // Private methods
    private void loadConfiguredRules() {
        List<ApexValidationRule__mdt> configuredRules = [
            SELECT
                DeveloperName,
                SObjectType__c,
                ConditionLogicType__c,
                CustomConditionLogic__c,
                ErrorMessage__c,
                (SELECT FieldPath__c, Operator__c, ValueType__c, Value__c FROM ApexValidationRuleConditions__r ORDER BY SortOrder__c),
                (SELECT Language__c, ErrorMessage__c FROM ApexValidationRuleTranslations__r)
            FROM ApexValidationRule__mdt
            WHERE SObjectType__c = :String.valueOf(this.sobjectType) AND IsActive__c = TRUE
        ];
        this.setRules(configuredRules);
    }

    public class ApexValidatorException extends Exception {
    }

    public class ApexValidationRuleResult {
        @AuraEnabled
        public List<String> conditions { get; private set; }
        @AuraEnabled
        public String conditionsLogic { get; private set; }
        @AuraEnabled
        public String conditionsLogicType { get; private set; }
        @AuraEnabled
        public String errorMessage { get; private set; }
        @AuraEnabled
        public Boolean hasError {
            get {
                return String.isNotBlank(this.errorMessage);
            }
            private set;
        }
        @AuraEnabled
        public Id recordId {
            get {
                return this.record.Id;
            }
            private set;
        }

        private SObject record;
        private ApexValidationRule__mdt rule;
        private List<ApexValidationRuleCondition__mdt> ruleConditions;

        public ApexValidationRuleResult(SObject record, ApexValidationRule__mdt rule, List<ApexValidationRuleCondition__mdt> ruleConditions) {
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
            for (ApexValidationRuleCondition__mdt ruleCondition : this.ruleConditions) {
                ApexValidationRuleConditionResult ruleConditionResult = new ApexValidationRuleConditionResult(this.record, ruleCondition);
                this.conditions.add(ruleConditionResult.getCondition());
                booleanValues.add(String.valueOf(ruleConditionResult.hasError));
            }

            String parsedConditionsLogic = String.format(this.getRuleConditionsLogic(), booleanValues);
            System.debug('parsedConditionsLogic==' + parsedConditionsLogic);

            Boolean hasError = new BooleanExpression().evaluate(parsedConditionsLogic);
            if (hasError) {
                this.errorMessage = this.getErrorMessage();
            }
        }

        private String getErrorMessage() {
            if (this.rule.ApexValidationRuleTranslations__r.isEmpty() == true) {
                return this.rule.ErrorMessage__c;
            }

            for (ApexValidationRuleTranslation__mdt translation : this.rule.ApexValidationRuleTranslations__r) {
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

                    parsedCharacters.add('{' + foundNumber + '}');
                    foundNumberString = '';
                    parsedCharacters.add(character);
                } else if (character.isNumeric()) {
                    hasFoundNumbers = true;
                    foundNumberString += character;
                } else if (hasFoundNumbers && !character.isNumeric() && !String.isBlank(foundNumberString)) {
                    Integer foundNumber = Integer.valueOf(foundNumberString) - 1;

                    parsedCharacters.add('{' + foundNumber + '}');
                    foundNumberString = '';
                } else {
                    parsedCharacters.add(character);
                }
            }
            return String.join(parsedCharacters, '').toUpperCase();
        }
    }

    private class ApexValidationRuleConditionResult {
        private Boolean hasError;
        private SObject record;
        private ApexValidationRuleCondition__mdt ruleCondition;
        private String sobjectApiName;

        private ApexValidationRuleConditionResult(SObject record, ApexValidationRuleCondition__mdt ruleCondition) {
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
                when Combobox {
                    return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue));
                }
                when Currency {
                    return this.compareDouble(Double.valueOf(recordFieldValue), Double.valueOf(comparisonValue));
                }
                when Date {
                    return this.compareDate(Date.valueOf(recordFieldValue), Date.valueOf(comparisonValue));
                }
                when Datetime {
                    return this.compareDatetime(Datetime.valueOf(recordFieldValue), Datetime.valueOf(comparisonValue));
                }
                when Double {
                    return this.compareDouble(Double.valueOf(recordFieldValue), Double.valueOf(comparisonValue));
                }
                when Email {
                    return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue));
                }
                when Id {
                    return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue));
                }
                when Integer {
                    return this.compareInteger(Integer.valueOf(recordFieldValue), Integer.valueOf(comparisonValue));
                }
                when MultiPicklist {
                    return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue));
                }
                when Percent {
                    return this.compareDouble(Double.valueOf(recordFieldValue), Double.valueOf(comparisonValue));
                }
                when Phone {
                    return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue));
                }
                when Picklist {
                    return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue));
                }
                when Reference {
                    return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue));
                }
                when String {
                    return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue));
                }
                when TextArea {
                    return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue));
                }
                when Url {
                    return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue));
                }
                when else {
                    throw new ApexValidatorException('Unknown operator: ' + this.ruleCondition.Operator__c);
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
                when 'Value' {
                    return this.ruleCondition.Value__c;
                }
                when else {
                    throw new ApexValidatorException('Unknown Value Type, cannot parse comparison value');
                }
            }
        }

        private Boolean compareBoolean(Boolean recordFieldValue, Boolean comparisonValue) {
            switch on this.ruleCondition.Operator__c {
                when '==' {
                    return recordFieldValue == comparisonValue;
                }
                when '!=' {
                    return recordFieldValue != comparisonValue;
                }
                when else {
                    throw new ApexValidatorException('Unknown operator: ' + this.ruleCondition.Operator__c);
                }
            }
        }

        private Boolean compareDate(Date recordFieldValue, Date comparisonValue) {
            switch on this.ruleCondition.Operator__c {
                when '==' {
                    return recordFieldValue == comparisonValue;
                }
                when '!=' {
                    return recordFieldValue != comparisonValue;
                }
                when '<' {
                    return recordFieldValue < comparisonValue;
                }
                when '<=' {
                    return recordFieldValue <= comparisonValue;
                }
                when '>' {
                    return recordFieldValue > comparisonValue;
                }
                when '>=' {
                    return recordFieldValue >= comparisonValue;
                }
                when else {
                    throw new ApexValidatorException('Unknown operator: ' + this.ruleCondition.Operator__c);
                }
            }
        }

        private Boolean compareDatetime(Datetime recordFieldValue, Datetime comparisonValue) {
            switch on this.ruleCondition.Operator__c {
                when '==' {
                    return recordFieldValue == comparisonValue;
                }
                when '!=' {
                    return recordFieldValue != comparisonValue;
                }
                when '<' {
                    return recordFieldValue < comparisonValue;
                }
                when '<=' {
                    return recordFieldValue <= comparisonValue;
                }
                when '>' {
                    return recordFieldValue > comparisonValue;
                }
                when '>=' {
                    return recordFieldValue >= comparisonValue;
                }
                when else {
                    throw new ApexValidatorException('Unknown operator: ' + this.ruleCondition.Operator__c);
                }
            }
        }

        private Boolean compareDouble(Double recordFieldValue, Double comparisonValue) {
            switch on this.ruleCondition.Operator__c {
                when '==' {
                    return recordFieldValue == comparisonValue;
                }
                when '!=' {
                    return recordFieldValue != comparisonValue;
                }
                when '<' {
                    return recordFieldValue < comparisonValue;
                }
                when '<=' {
                    return recordFieldValue <= comparisonValue;
                }
                when '>' {
                    return recordFieldValue > comparisonValue;
                }
                when '>=' {
                    return recordFieldValue >= comparisonValue;
                }
                when else {
                    throw new ApexValidatorException('Unknown operator: ' + this.ruleCondition.Operator__c);
                }
            }
        }

        private Boolean compareInteger(Integer recordFieldValue, Integer comparisonValue) {
            switch on this.ruleCondition.Operator__c {
                when '==' {
                    return recordFieldValue == comparisonValue;
                }
                when '!=' {
                    return recordFieldValue != comparisonValue;
                }
                when '<' {
                    return recordFieldValue < comparisonValue;
                }
                when '<=' {
                    return recordFieldValue <= comparisonValue;
                }
                when '>' {
                    return recordFieldValue > comparisonValue;
                }
                when '>=' {
                    return recordFieldValue >= comparisonValue;
                }
                when else {
                    throw new ApexValidatorException('Unknown operator: ' + this.ruleCondition.Operator__c);
                }
            }
        }

        private Boolean compareString(String recordFieldValue, String comparisonValue) {
            switch on this.ruleCondition.Operator__c {
                when '==' {
                    return recordFieldValue == comparisonValue;
                }
                when '!=' {
                    return recordFieldValue != comparisonValue;
                }
                when '<' {
                    return recordFieldValue < comparisonValue;
                }
                when '<=' {
                    return recordFieldValue <= comparisonValue;
                }
                when '>' {
                    return recordFieldValue > comparisonValue;
                }
                when '>=' {
                    return recordFieldValue >= comparisonValue;
                }
                when else {
                    throw new ApexValidatorException('Unknown operator: ' + this.ruleCondition.Operator__c);
                }
            }
        }
    }

    //https://salesforce.stackexchange.com/questions/113300/boolean-evaluation-in-apex/113308
    public class BooleanExpression {
        public Boolean evaluate(String x) {
            x = simplify(x);

            if (isSimpleExpression(x))
                return Boolean.valueOf(x);

            if (x.contains('&&')) {
                return andJoin(x.split('&&', 2)[0], x.split('&&', 2)[1]);
            }
            if (x.contains('||')) {
                String p1 = x.split('\\|\\|', 2)[0];
                String p2 = x.split('\\|\\|', 2)[1];

                return orJoin(p1, p2);
            }
            if (x.startsWith('!'))
                return !evaluate(x.substring(1));

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
            while (x.contains('(')) {
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

        public FieldPath(Schema.SObjectType sobjectType, Schema.SObjectField field) {
            this(sobjectType, new List<Schema.SObjectField>{ field });
        }

        public FieldPath(Schema.SObjectType sobjectType, List<Schema.SObjectField> fieldChain) {
            this.sobjectType = sobjectType;
            this.fieldChain = fieldChain;
            this.fieldPath = this.getQueryField(fieldChain);

            this.fieldDescribe = this.getLastFieldDescribe();
        }

        public Schema.DescribeFieldResult getDescribe() {
            return this.fieldDescribe;
        }

        public Schema.SObjectField getField() {
            return this.fieldChain[this.fieldChain.size() - 1];
        }

        public String getFieldPath() {
            return this.fieldPath;
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

        private String getQueryField(List<Schema.SObjectField> fields) {
            Integer lastFieldIndex = fields.size() - 1;
            List<String> fieldPathPieces = new List<String>();
            for (Integer i = 0; i < fields.size(); i++) {
                SObjectField field = fields[i];
                // If any field in the chain is not accessible, then the user cant access the data, so return an empty list
                if (!field.getDescribe().isAccessible()) {
                    return null;
                } else if (i == lastFieldIndex) {
                    fieldPathPieces.add(field.getDescribe().getName());
                } else {
                    fieldPathPieces.add(field.getDescribe().getRelationshipName());
                }
            }
            return String.join(fieldPathPieces, '.');
        }
    }
}
