public class JSONGeneratorHandler {

    private String calloutName;
    private sObject sobjectRecord;
    
    private JSON_Generator__mdt startingProperty; 
    private Map<String, List<JSON_Generator__mdt>> jsonPropertyMap; 
    private JSONGenerator generator;
	
	public boolean includeNullValues;
    
    public class JSONGeneratorException extends Exception {}
    
    public JSONGeneratorHandler(String calloutName, sObject sobjectRecord){
        this.calloutName = calloutName;
        this.sobjectRecord = sobjectRecord;
        this.jsonPropertyMap = new Map<String, List<JSON_Generator__mdt>>();
		this.includeNullValues = false;
        this.initialize(null);
    }
    
    public JSONGeneratorHandler(String calloutName, String whereClause){
        this.calloutName = calloutName;
        this.jsonPropertyMap = new Map<String, List<JSON_Generator__mdt>>();
		this.includeNullValues = false;
        this.initialize(whereClause);
    }
    
    public String getJSON(){
        if(this.startingProperty == null){
            throw new JSONGeneratorException('Starting point not found.');
        }
        if(this.sobjectRecord == null){
            throw new JSONGeneratorException('Mapping record not found.');
        }
        generator = JSON.createGenerator(false);
        addJSONProperty(startingProperty);
        return generator.getAsString();
    }
    
    private void addJSONProperty(JSON_Generator__mdt property){
        if(property.Property_Type__c == 'Array'){
			generator.writeFieldName(property.Property_Name__c);
            generator.writeStartArray();
            processAllChilds(property.DeveloperName);
            generator.writeEndArray();
            
        }else if(property.Property_Type__c == 'Object'){
            generator.writeStartObject();
            processAllChilds(property.DeveloperName);
            generator.writeEndObject();
            
        }else if(property.Property_Type__c == 'Value'){
			String fieldValue;
            if(property.Apex_Class_API_Name__c == null && property.Static_Value__c == null){
                if(property.Property_Name__c == null){
                    generator.writeString(this.getFieldValue(property.Object_Field_API_Name__c));
                }else{
					fieldValue = this.getFieldValue(property.Object_Field_API_Name__c);
					if(String.isNotEmpty(fieldValue)){
						System.debug(fieldValue);
						generator.writeStringField(property.Property_Name__c, fieldValue);	
					}else if(includeNullValues){
						generator.writeNullField(property.Property_Name__c);
					}
                    
                }
            }else if(property.Apex_Class_API_Name__c == null && property.Static_Value__c != null){
				if(property.Property_Name__c == null){
                    generator.writeString(property.Static_Value__c);
                }else{
					generator.writeStringField(property.Property_Name__c, property.Static_Value__c);
                }
			}else if(property.Apex_Class_API_Name__c != null && property.Static_Value__c == null){
                JSONPropertyInterface propInterface = (JSONPropertyInterface) Type.forName(property.Apex_Class_API_Name__c).newInstance();
                if(property.Property_Name__c == null){
                    generator.writeString(propInterface.getValue(sobjectRecord));
                }else{
                    generator.writeStringField(property.Property_Name__c, propInterface.getValue(sobjectRecord));
                }
            }
        }
    }
    
    private void processAllChilds(String parentName){
        for(JSON_Generator__mdt property : this.jsonPropertyMap.get(parentName)){
            addJSONProperty(property);
        }
    }
    
    private void initialize(String whereClause){
        String sobjectName = null;
        Set<String> soqlFields = new Set<String>();
        for(JSON_Generator__mdt jsonGeneratorRec : [SELECT  DeveloperName, 
                                                            Apex_Class_API_Name__c, 
                                                            Is_Start__c, 
                                                            Object_Field_API_Name__c, 
                                                            Parent_JSON_Generator__c, 
                                                            Property_Name__c, 
                                                            Property_Type__c,
                                                            sObject_Name__c,
															Static_Value__c
                                                    FROM    JSON_Generator__mdt
                                                    WHERE   Callout_Name__c = :this.calloutName
                                                    AND     Is_Disabled__c = false]){
            if(jsonGeneratorRec.Is_Start__c){
                startingProperty = jsonGeneratorRec;
                sobjectName = jsonGeneratorRec.sObject_Name__c;
            }
            if(String.isNotEmpty(jsonGeneratorRec.Parent_JSON_Generator__c)){
                if(!jsonPropertyMap.containsKey(jsonGeneratorRec.Parent_JSON_Generator__c)){
                    jsonPropertyMap.put(jsonGeneratorRec.Parent_JSON_Generator__c, new List<JSON_Generator__mdt>());
                }
                jsonPropertyMap.get(jsonGeneratorRec.Parent_JSON_Generator__c).add(jsonGeneratorRec);
                if(String.isNotEmpty(jsonGeneratorRec.Object_Field_API_Name__c)){
                    soqlFields.add(jsonGeneratorRec.Object_Field_API_Name__c);
                }
            }
        }
        if(String.isNotEmpty(whereClause) && soqlFields.size() > 0){
            getRecord(sobjectName, soqlFields, whereClause);
        }
    }
    
    private void getRecord(String sobjectName, Set<String> soqlFields, String whereClause){
        if(startingProperty == null){
            throw new JSONGeneratorException('Starting point not found.');
        }
        try{
            List<sObject> sobjList = Database.query('SELECT '+String.join(new List<String>(soqlFields), ', ')+' FROM '+sobjectName+' '+whereClause);
            if(sobjList.size() > 1){
                throw new JSONGeneratorException('More than one record found, Please refine the where clause.');
            }
            if(sobjList.size() == 0){
                throw new JSONGeneratorException('No record found, Please refine the where clause.');
            }
            if(sobjList.size() == 1)
                this.sobjectRecord = sobjList[0];
        }catch(Exception ex){
            throw ex;
        }
    }
    
    private String getFieldValue(String fieldName){
        List<String> objectFields = fieldName.split('\\.');
        sObject record = this.sobjectRecord;
        String value = '';
        for(Integer i = 0; i < objectFields.size(); i++){
            if(i == objectFields.size() - 1){
                value = String.valueOf(record.get(objectFields[i]));
            }else{
                record = record.getSobject(objectFields[i]);
            }
        }
        return value;
    }
    
}