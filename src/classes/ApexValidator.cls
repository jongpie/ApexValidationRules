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

    public List<ApexValidationRuleResult> getResults() {
        System.debug('getResults');

        List<ApexValidationRuleResult> results = new List<ApexValidationRuleResult>();
        for(SObject record : this.records) {
            for(ApexValidationRule__mdt rule : this.rules) {
                results.add(new ApexValidationRuleResult(record, rule));
            }
        }

        return results;
    }

    private List<ApexValidationRule__mdt> getRules() {
        System.debug('getRules');
        System.debug('String.valueOf(this.sobjectType)=' + String.valueOf(this.sobjectType));
        return [
            SELECT SObjectType__c, ErrorMessage__c, (
                    SELECT SObjectType__c, Field__c, Field__r.QualifiedApiName, Operator__c, ValueType__c, Value__c
                    FROM ApexValidationRuleCriteria__r
                )
            FROM ApexValidationRule__mdt
            WHERE SObjectType__c = :String.valueOf(this.sobjectType)
            AND IsActive__c = true
        ];
    }

    private class ApexValidatorException extends Exception {}

    private class ApexValidationRuleResult {

        //private String errorMessage;
        private List<String> errorMessages;
        private Boolean hasErrors {get { return this.errorMessages.size() > 0; } }
        private Id recordId;
        //private List<ApexValidationRuleCriterionResult> ruleCriteriaResults;

        private SObject record;
        private ApexValidationRule__mdt rule;

        public ApexValidationRuleResult(SObject record, ApexValidationRule__mdt rule) {
            this.recordId            = record.Id;
            this.record              = record;
            this.rule                = rule;
            this.errorMessages = new List<String>();
            //this.ruleCriteriaResults = new List<ApexValidationRuleCriterionResult>();

            this.getResults();
        }

        public void getResults() {
            System.debug('looping through rule ID: ' + this.rule.Id);
            for(ApexValidationRuleCriterion__mdt ruleCriterion : this.rule.ApexValidationRuleCriteria__r) {
                System.debug('ruleCriterion=' + ruleCriterion);
                ApexValidationRuleCriterionResult ruleCriterionResult = new ApexValidationRuleCriterionResult(this.record, ruleCriterion);
                //this.isInvalid = ruleCriterionResult.isInvalid;
                //this.ruleCriteriaResults.add(ruleCriterionResult);


                if(ruleCriterionResult.hasError) this.errorMessages.add(this.rule.ErrorMessage__c);
                //if(isInvalid) record.addError(this.rule.ErrorMessage__c);
                //if(isInvalid) this.errorMessage = this.rule.ErrorMessage__c;
            }
        }

    }

    private class ApexValidationRuleCriterionResult {

        private Boolean hasError;
        private SObject record;
        private ApexValidationRuleCriterion__mdt ruleCriterion;

        private ApexValidationRuleCriterionResult(SObject record, ApexValidationRuleCriterion__mdt ruleCriterion) {
            this.record        = record;
            this.ruleCriterion = ruleCriterion;

            this.hasError = this.getHasError();
        }

        public Boolean getHasError() {
            if(this.ruleCriterion.ValueType__c == 'RegEx') return this.getHasRegExError();

            // TODO add support for field paths
            Schema.SObjectField field = this.record.getSObjectType().getDescribe().fields.getMap().get(this.ruleCriterion.Field__r.QualifiedApiName);
System.debug('current rule ruleCriterion=' + this.ruleCriterion);
            Object recordFieldValue = this.getFieldValue();
            Object comparisonValue  = this.getComparisonValue();
System.debug('recordFieldValue=' + recordFieldValue);
System.debug('comparisonValue=' + comparisonValue);
            switch on field.getDescribe().getSoapType() {
                when Boolean  { return this.compareBoolean(Boolean.valueOf(recordFieldValue), Boolean.valueOf(comparisonValue)); }
                when Date     { return this.compareDate(Date.valueOf(recordFieldValue), Date.valueOf(comparisonValue)); }
                when Datetime { return this.compareDatetime(Datetime.valueOf(recordFieldValue), Datetime.valueOf(comparisonValue)); }
                when Double   { return this.compareDouble(Double.valueOf(recordFieldValue), Double.valueOf(comparisonValue)); }
                when Id       { return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue)); }
                when Integer  { return this.compareInteger(Integer.valueOf(recordFieldValue), Integer.valueOf(comparisonValue)); }
                when String   { return this.compareString(String.valueOf(recordFieldValue), String.valueOf(comparisonValue)); }
                //when Time     { return this.compareTime(Time.valueOf(recordFieldValue), Time.valueOf(comparisonValue)); }
                when else     { throw new ApexValidatorException('Unknown operator: ' + this.ruleCriterion.Operator__c); }
            }
        }

        private Boolean getHasRegExError() {
            Pattern pattern = Pattern.compile(this.ruleCriterion.Value__c);
            return pattern.matcher(String.valueOf(this.getFieldValue())).matches();
       }

        private Object getFieldValue() {
            return this.record.get(this.ruleCriterion.Field__r.QualifiedApiName);
        }

        private Object getComparisonValue() {
            switch on this.ruleCriterion.ValueType__c {
                when 'Static Value' { return this.ruleCriterion.Value__c; }
                when 'Field Value'  { return record.get(this.ruleCriterion.Value__c); }
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
            System.debug('compareDouble(' + recordFieldValue + ', ' + comparisonValue + ')');
            System.debug('this.ruleCriterion.Operator__c=' + this.ruleCriterion.Operator__c);

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

        private Boolean compareId(Id recordFieldValue, Id comparisonValue) {
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

        private Boolean compareTime(Time recordFieldValue, Time comparisonValue) {
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

}