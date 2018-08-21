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
            record.recalculateFormulas();
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
            SELECT SObjectType__c, CriteriaLogicType__c, CustomCriteriaLogic__c, ErrorMessage__c,
                (
                    SELECT SObjectType__c, Field__c, Field__r.QualifiedApiName, Operator__c, ValueType__c, Value__c
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

    private class ApexValidatorException extends Exception {}

    private class ApexValidationRuleResult {

        @AuraEnabled public String criteriaLogicType   { get; private set; }
        @AuraEnabled public String criteriaLogic       { get; private set; }
        @AuraEnabled public List<String> errorMessages { get; private set; }
        @AuraEnabled public Boolean hasErrors          { get { return this.errorMessages.size() > 0; } private set; }
        @AuraEnabled public Id recordId                { get { return this.record.Id; } private set; }

        private SObject record;
        private ApexValidationRule__mdt rule;

        public ApexValidationRuleResult(SObject record, ApexValidationRule__mdt rule) {
            this.errorMessages = new List<String>();
            this.record        = record;
            //this.recordId      = record.Id;
            this.rule          = rule;

            this.criteriaLogicType = rule.CriteriaLogicType__c;
            this.criteriaLogic = this.getRuleCriteriaLogic();

            this.process();
        }

        private void process() {
            System.debug('looping through rule ID: ' + this.rule.Id);
            List<String> booleanValues = new List<String>();
            for(ApexValidationRuleCriterion__mdt ruleCriterion : this.rule.ApexValidationRuleCriteria__r) {
                System.debug('ruleCriterion=' + ruleCriterion);
                ApexValidationRuleCriterionResult ruleCriterionResult = new ApexValidationRuleCriterionResult(this.record, ruleCriterion);
                booleanValues.add(String.valueOf(ruleCriterionResult.hasError));
                //this.isInvalid = ruleCriterionResult.isInvalid;
                //this.ruleCriteriaResults.add(ruleCriterionResult);


                if(ruleCriterionResult.hasError && String.isBlank(this.rule.CustomCriteriaLogic__c)) this.errorMessages.add(this.getErrorMessage());
                //if(isInvalid) record.addError(this.rule.ErrorMessage__c);
                //if(isInvalid) this.errorMessage = this.rule.ErrorMessage__c;
            }
            if(String.isBlank(this.rule.CustomCriteriaLogic__c)) return;

            String criteriaLogic = String.format(this.rule.CustomCriteriaLogic__c, booleanValues);
            this.criteriaLogic = criteriaLogic;
            System.debug('criteriaLogic criteriaLogic=' + criteriaLogic);
            Boolean hasError = new BooleanExpression().evaluate(criteriaLogic);
            System.debug('criteriaLogic hasError=' + hasError);
        }

        private String getErrorMessage() {
            if(this.rule.ApexValidationRuleTranslations__r.isEmpty()) return this.rule.ErrorMessage__c;

            for(ApexValidationRuleTranslation__mdt translation : this.rule.ApexValidationRuleTranslations__r) {
                if(translation.Language__c == UserInfo.getLanguage()) return translation.ErrorMessage__c;
            }

            return this.rule.ErrorMessage__c;
        }

        private String getRuleCriteriaLogic() {
            if(this.rule.CriteriaLogicType__c != 'Custom') {
                List<String> standardLogicPieces = new List<String>();
                for(Integer i = 0; i < this.rule.ApexValidationRuleCriteria__r.size(); i++) {
                    standardLogicPieces.add(' {' + String.valueOf(i) + '} ');
                }
                return String.join(standardLogicPieces, this.rule.CriteriaLogicType__c);
            }

            List<String> parsedCharacters = new List<String>();
            Boolean hasFoundNumbers = false;
            String foundNumberString = '';

            for(String character : this.rule.CustomCriteriaLogic__c.split('')) {
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

        private ApexValidationRuleCriterionResult(SObject record, ApexValidationRuleCriterion__mdt ruleCriterion) {
            this.record        = record;
            this.ruleCriterion = ruleCriterion;

            this.hasError = this.getHasError();
        }

        public Boolean getHasError() {
            if(this.ruleCriterion.ValueType__c == 'RegEx') return this.getHasRegExError();

            // TODO add support for field paths
            Schema.SObjectField field = this.record.getSObjectType().getDescribe().fields.getMap().get(this.ruleCriterion.Field__r.QualifiedApiName);

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
            // TODO add support for field paths
            return this.record.get(this.ruleCriterion.Field__r.QualifiedApiName);
        }

        private Object getComparisonValue() {
            switch on this.ruleCriterion.ValueType__c {
                // TODO add support for field paths
                when 'Field Value'  { return record.get(this.ruleCriterion.Value__c); }
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

}