/*****************************************************************************************************
* This file is part of the Apex Validation Rules project, released under the MIT License.            *
* See LICENSE file or go to https://github.com/jongpie/ApexValidationRules for full license details. *
*****************************************************************************************************/
public without sharing class ApexValidator {

    private List<SObject> records;
    List<ApexValidationRule__mdt> rules;
    private Schema.SObjectType sobjectType;

    public ApexValidator(SObject record) {
        this(new List<SObject>{record});
    }

    public ApexValidator(List<SObject> records) {
        this.records     = records;
        this.sobjectType = records[0].getSObjectType();

        this.rules = this.getRules();
    }

    public ApexValidator setRules(List<ApexValidationRule__mdt> rules) {
        this.rules = this.queryRules(rules);
        return this;
    }

    public List<ApexValidationRuleResult> getResults() {
        return this.validate(false);
    }

    public List<ApexValidationRuleResult> validate() {
        return this.validate(true);
    }

    private List<ApexValidationRuleResult> validate(Boolean shouldThrowException) {
        List<ApexValidationRuleResult> results = new List<ApexValidationRuleResult>();
        for(SObject record : this.records) {
            record.recalculateFormulas();
            for(ApexValidationRule__mdt rule : this.rules) {
                ApexValidationRuleResult ruleResult = new ApexValidationRuleResult(record, rule);

                if(shouldThrowException && ruleResult.hasError) throw new ApexValidatorException(ruleResult.errorMessage);

                results.add(ruleResult);
            }
        }
        return results;
    }

    private List<ApexValidationRule__mdt> getRules() {
        return [
            SELECT SObjectType__c, CriteriaLogicType__c, CustomCriteriaLogic__c, ErrorMessage__c,
                (
                    SELECT FieldPath__c, Operator__c, ValueType__c, Value__c
                    FROM ApexValidationRuleCriteria__r
                    ORDER BY SortOrder__c
                ),
                (
                    SELECT Language__c, ErrorMessage__c
                    FROM ApexValidationRuleTranslations__r
                )
            FROM ApexValidationRule__mdt
            WHERE SObjectType__c = :String.valueOf(this.sobjectType)
            AND IsActive__c = true
        ];
    }

    private List<ApexValidationRule__mdt> queryRules(List<ApexValidationRule__mdt> rules) {
        return [
            SELECT SObjectType__c, CriteriaLogicType__c, CustomCriteriaLogic__c, ErrorMessage__c,
                (
                    SELECT FieldPath__c, Operator__c, ValueType__c, Value__c
                    FROM ApexValidationRuleCriteria__r
                    ORDER BY SortOrder__c
                ),
                (
                    SELECT Language__c, ErrorMessage__c
                    FROM ApexValidationRuleTranslations__r
                )
            FROM ApexValidationRule__mdt
            WHERE SObjectType__c = :String.valueOf(this.sobjectType)
            AND Id IN :rules
        ];
    }

    public class ApexValidatorException extends Exception {}

    private class ApexValidationRuleResult {

        @AuraEnabled public List<String> criteria    { get; private set; }
        @AuraEnabled public String criteriaLogic     { get; private set; }
        @AuraEnabled public String criteriaLogicType { get; private set; }
        @AuraEnabled public String errorMessage      { get; private set; }
        @AuraEnabled public Boolean hasError         { get { return !String.isBlank(this.errorMessage); } private set; }
        @AuraEnabled public Id recordId              { get { return this.record.Id; } private set; }

        private SObject record;
        private ApexValidationRule__mdt rule;

        public ApexValidationRuleResult(SObject record, ApexValidationRule__mdt rule) {
            this.record = record;
            this.rule   = rule;

            this.criteria          = new List<String>();
            this.criteriaLogic     = this.getRuleCriteriaLogic();
            this.criteriaLogicType = rule.CriteriaLogicType__c;

            this.process();
        }

        private void process() {
            List<String> booleanValues = new List<String>();
            for(ApexValidationRuleCriterion__mdt ruleCriterion : this.rule.ApexValidationRuleCriteria__r) {
                ApexValidationRuleCriterionResult ruleCriterionResult = new ApexValidationRuleCriterionResult(this.record, ruleCriterion);
                this.criteria.add(ruleCriterionResult.getCriterion());
                booleanValues.add(String.valueOf(ruleCriterionResult.hasError));
            }
            //if(String.isBlank(this.rule.CustomCriteriaLogic__c)) return;

            this.criteriaLogic = String.format(this.getRuleCriteriaLogic(), booleanValues);
            Boolean hasError = new BooleanExpression().evaluate(this.criteriaLogic);
            if(hasError) this.errorMessage = this.getErrorMessage();
        }

        private String getErrorMessage() {
            if(this.rule.ApexValidationRuleTranslations__r.isEmpty()) return this.rule.ErrorMessage__c;

            for(ApexValidationRuleTranslation__mdt translation : this.rule.ApexValidationRuleTranslations__r) {
                if(translation.Language__c == UserInfo.getLanguage()) return translation.ErrorMessage__c;
            }

            return this.rule.ErrorMessage__c;
        }

        private String getRuleCriteriaLogic() {
            String criteriaLogic = String.isBlank(this.rule.CustomCriteriaLogic__c) ? '' : this.rule.CustomCriteriaLogic__c;

            if(this.rule.CriteriaLogicType__c != 'Custom') {
                List<String> standardLogicPieces = new List<String>();
                for(Integer i = 0; i < this.rule.ApexValidationRuleCriteria__r.size(); i++) {
                    standardLogicPieces.add(String.valueOf(i + 1));
                }
                criteriaLogic = '(' + String.join(standardLogicPieces, ' ' + this.rule.CriteriaLogicType__c + ' ') + ')';
            }

            List<String> parsedCharacters = new List<String>();
            Boolean hasFoundNumbers = false;
            String foundNumberString = '';

            for(String character : criteriaLogic.split('')) {
                if(!character.isNumeric() && !hasFoundNumbers) {
                    parsedCharacters.add(character);
                } else if(!character.isNumeric() && hasFoundNumbers){
                    hasFoundNumbers = false;
                    Integer foundNumber = Integer.valueOf(foundNumberString) - 1;

                    parsedCharacters.add('{' + foundNumber + '}');
                    foundNumberString = '';
                    parsedCharacters.add(character);
                } else if(character.isNumeric()) {
                    hasFoundNumbers = true;
                    foundNumberString += character;
                } else if(hasFoundNumbers && !character.isNumeric() && !String.isBlank(foundNumberString)) {
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

    private class ApexValidationRuleCriterionResult {

        private Boolean hasError;
        private SObject record;
        private ApexValidationRuleCriterion__mdt ruleCriterion;
        private String sobjectApiName;

        private ApexValidationRuleCriterionResult(SObject record, ApexValidationRuleCriterion__mdt ruleCriterion) {
            this.record        = record;
            this.ruleCriterion = ruleCriterion;
            this.sobjectApiName = this.record.getSObjectType().getDescribe().getName();

            this.hasError = this.getHasError();
        }

        public String getCriterion() {
            return this.ruleCriterion.FieldPath__c
                + ' ' + this.ruleCriterion.Operator__c
                + ' ' + this.getComparisonValue() + ' (' + this.ruleCriterion.ValueType__c + ')';
        }

        public Boolean getHasError() {
            if(this.ruleCriterion.ValueType__c == 'RegEx') return this.getHasRegExError();

            Schema.SObjectField field = new FieldPath(this.sobjectApiName, this.ruleCriterion.FieldPath__c).getField();

            Object recordFieldValue = this.getFieldValue();
            Object comparisonValue  = this.getComparisonValue();

            switch on field.getDescribe().getSoapType() {
                when Boolean  { return this.compareBoolean(Boolean.valueOf(recordFieldValue), Boolean.valueOf(comparisonValue)); }
                when Date     { return this.compareDate(Date.valueOf(recordFieldValue), Date.valueOf(comparisonValue)); }
                when Datetime { return this.compareDatetime(Datetime.valueOf(recordFieldValue), Datetime.valueOf(comparisonValue)); }
                when Double   { return this.compareDouble(Double.valueOf(recordFieldValue), Double.valueOf(comparisonValue)); }
                when Id       { return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue)); }
                when Integer  { return this.compareInteger(Integer.valueOf(recordFieldValue), Integer.valueOf(comparisonValue)); }
                when String   { return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue)); }
                when else     { throw new ApexValidatorException('Unknown operator: ' + this.ruleCriterion.Operator__c); }
            }
        }

        private Boolean getHasRegExError() {
            Pattern pattern = Pattern.compile(this.ruleCriterion.Value__c);
            return pattern.matcher(String.valueOf(this.getFieldValue())).matches();
       }

        private Object getFieldValue() {
            return new FieldPath(this.sobjectApiName, this.ruleCriterion.FieldPath__c).getValue(this.record);
        }

        private Object getComparisonValue() {
            switch on this.ruleCriterion.ValueType__c {
                when 'Field Value'  { return new FieldPath(this.sobjectApiName, this.ruleCriterion.Value__c).getValue(this.record); }
                when 'Static Value' { return this.ruleCriterion.Value__c; }
                when else           { throw new ApexValidatorException('Unknown Value Type, cannot parse comparison value'); }
            }
        }

        private Boolean compareBoolean(Boolean recordFieldValue, Boolean comparisonValue) {
            switch on this.ruleCriterion.Operator__c {
                when '==' { return recordFieldValue == comparisonValue; }
                when '!=' { return recordFieldValue != comparisonValue; }
                when else { throw new ApexValidatorException('Unknown operator: ' + this.ruleCriterion.Operator__c); }
            }
        }

        private Boolean compareDate(Date recordFieldValue, Date comparisonValue) {
            switch on this.ruleCriterion.Operator__c {
                when '==' { return recordFieldValue == comparisonValue; }
                when '!=' { return recordFieldValue != comparisonValue; }
                when '<'  { return recordFieldValue <  comparisonValue; }
                when '<=' { return recordFieldValue <= comparisonValue; }
                when '>'  { return recordFieldValue >  comparisonValue; }
                when '>=' { return recordFieldValue >= comparisonValue; }
                when else { throw new ApexValidatorException('Unknown operator: ' + this.ruleCriterion.Operator__c); }
            }
        }

        private Boolean compareDatetime(Datetime recordFieldValue, Datetime comparisonValue) {
            switch on this.ruleCriterion.Operator__c {
                when '==' { return recordFieldValue == comparisonValue; }
                when '!=' { return recordFieldValue != comparisonValue; }
                when '<'  { return recordFieldValue <  comparisonValue; }
                when '<=' { return recordFieldValue <= comparisonValue; }
                when '>'  { return recordFieldValue >  comparisonValue; }
                when '>=' { return recordFieldValue >= comparisonValue; }
                when else { throw new ApexValidatorException('Unknown operator: ' + this.ruleCriterion.Operator__c); }
            }
        }

        private Boolean compareDouble(Double recordFieldValue, Double comparisonValue) {
            switch on this.ruleCriterion.Operator__c {
                when '==' { return recordFieldValue == comparisonValue; }
                when '!=' { return recordFieldValue != comparisonValue; }
                when '<'  { return recordFieldValue <  comparisonValue; }
                when '<=' { return recordFieldValue <= comparisonValue; }
                when '>'  { return recordFieldValue >  comparisonValue; }
                when '>=' { return recordFieldValue >= comparisonValue; }
                when else { throw new ApexValidatorException('Unknown operator: ' + this.ruleCriterion.Operator__c); }
            }
        }

        private Boolean compareInteger(Integer recordFieldValue, Integer comparisonValue) {
            switch on this.ruleCriterion.Operator__c {
                when '==' { return recordFieldValue == comparisonValue; }
                when '!=' { return recordFieldValue != comparisonValue; }
                when '<'  { return recordFieldValue <  comparisonValue; }
                when '<=' { return recordFieldValue <= comparisonValue; }
                when '>'  { return recordFieldValue >  comparisonValue; }
                when '>=' { return recordFieldValue >= comparisonValue; }
                when else { throw new ApexValidatorException('Unknown operator: ' + this.ruleCriterion.Operator__c); }
            }
        }

        private Boolean compareString(String recordFieldValue, String comparisonValue) {
            switch on this.ruleCriterion.Operator__c {
                when '==' { return recordFieldValue == comparisonValue; }
                when '!=' { return recordFieldValue != comparisonValue; }
                when '<'  { return recordFieldValue <  comparisonValue; }
                when '<=' { return recordFieldValue <= comparisonValue; }
                when '>'  { return recordFieldValue >  comparisonValue; }
                when '>=' { return recordFieldValue >= comparisonValue; }
                when else { throw new ApexValidatorException('Unknown operator: ' + this.ruleCriterion.Operator__c); }
            }
        }

    }

    //https://salesforce.stackexchange.com/questions/113300/boolean-evaluation-in-apex/113308
    public class BooleanExpression {

        public Boolean evaluate(String x) {
            x = simplify(x);

            if(isSimpleExpression(x)) return Boolean.valueOf(x);

            if(x.contains('&&')) {
                return andJoin(x.split('&&', 2)[0], x.split('&&', 2)[1]);
            }
            if(x.contains('||')) {
                String p1 = x.split('\\|\\|', 2)[0];
                String p2 = x.split('\\|\\|', 2)[1];
                System.debug('p1=' + p1);
                System.debug('p2=' + p2);
                return orJoin(p1, p2);
            }
            if(x.startsWith('!')) return !evaluate(x.substring(1));

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
            while(x.contains('(')) {
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
            this.fieldPath  = fieldPath;

            this.fieldDescribe  = this.getLastFieldDescribe();
        }

        public FieldPath(Schema.SObjectType sobjectType, Schema.SObjectField field) {
            this(sobjectType, new List<Schema.SObjectField>{field});
        }

        public FieldPath(Schema.SObjectType sobjectType, List<Schema.SObjectField> fieldChain) {
            this.sobjectType = sobjectType;
            this.fieldChain = fieldChain;
            this.fieldPath  = this.getQueryField(fieldChain);

            this.fieldDescribe  = this.getLastFieldDescribe();
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
            SObject parentRecord                 = record;

            for(Schema.SObjectField field : this.fieldChain) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                String relationshipName                  = fieldDescribe.getRelationshipName();

                if(fieldDescribe.getSoapType() != Schema.SoapType.Id) {
                    return parentRecord.get(fieldDescribe.getName());
                } else {
                    parentSObjectType = fieldDescribe.getReferenceTo()[0];

                    SObject newParentRecord = parentRecord.getSObject(field);
                    if(newParentRecord == null) return null;
                    else parentRecord = newParentRecord;
                }
            }

            return null;
        }

        private List<Schema.SObjectField> getFieldChain(Schema.SObjectType sobjectType, String fieldPath) {
            Schema.SObjectType currentSObjectType = sobjectType;

            List<Schema.SObjectField> fields = new List<Schema.SObjectField>();
            List<String> fieldPathPieces = fieldPath.split('\\.');
            Integer lastFieldIndex = fieldPathPieces.size() <= 1 ? 0 : fieldPathPieces.size() - 1;

            for(Integer i = 0; i < fieldPathPieces.size(); i++) {
                String fieldPathPiece = fieldPathPieces[i];

                String fieldApiName;
                if(i == lastFieldIndex) fieldApiName = fieldPathPiece;
                else if(fieldPathPiece.endsWith('__r')) fieldApiName = fieldPathPiece.replace('__r', '__c');
                else fieldApiName = fieldPathPiece + 'Id';

                Schema.SObjectField field = currentSObjectType.getDescribe().fields.getMap().get(fieldApiName);

                // TODO add support for polymorphic fields
                if(i < lastFieldIndex) currentSObjectType = field.getDescribe().getReferenceTo()[0];

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
            for(Integer i = 0; i < fields.size(); i++) {
                SObjectField field = fields[i];
                // If any field in the chain is not accessible, then the user cant access the data, so return an empty list
                if(!field.getDescribe().isAccessible()) return null;
                else if(i == lastFieldIndex) fieldPathPieces.add(field.getDescribe().getName());
                else fieldPathPieces.add(field.getDescribe().getRelationshipName());
            }
            return String.join(fieldPathPieces, '.');
        }

    }

}