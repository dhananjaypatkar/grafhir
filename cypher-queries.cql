/* Create constraints to ensure unique ids for resource types*/
CREATE CONSTRAINT pid on (p:Patient) ASSERT p.id IS UNIQUE;
CREATE CONSTRAINT prid ON (p:Practitioner) ASSERT p.id IS UNIQUE;
CREATE CONSTRAINT orgid ON (o:Organization) ASSERT o.id IS UNIQUE;
CREATE CONSTRAINT encid ON (e:Encounter) ASSERT e.id_name IS UNIQUE;
CREATE CONSTRAINT cond ON (c:Condition) ASSERT c.id IS UNIQUE;
CREATE CONSTRAINT obs ON (o:Observation) ASSERT o.id IS UNIQUE;
CREATE CONSTRAINT mr ON (m:MedicationRequest) ASSERT m.id IS UNIQUE;
CREATE CONSTRAINT pr ON (pr:Procedure) ASSERT pr.id IS UNIQUE;

#Patient Node
call apoc.load.json("a.json") yield value unwind value.entry as ent    
with ent
where ent.resource.resourceType ="Patient"
Create (p: Patient {lname: ent.resource.name[0].family, fname: ent.resource.name[0].given[0], 
sex: ent.resource.gender, birthDate: ent.resource.birthDate, state: ent.resource.address[0].state, 
city: ent.resource.address[0].city, zip: ent.resource.address[0].postalCode, id: ent.resource.id, 
race: ent.resource.extension[0].extension[0].valueCoding.display, 
ethinicity: ent.resource.extension[1].extension[0].valueCoding.display})
})

#Practitioner Node
call apoc.load.json("a.json") yield value unwind value.entry as ent
with ent
where ent.resource.resourceType ="Practitioner"
CREATE (prov: Practitioner {fname: ent.resource.name[0].given[0], name: ent.resource.name[0].family, gender: ent.resource.gender, id: ent.resource.id})


#Organization Node
call apoc.load.json("a.json") yield value unwind value.entry as ent
with ent
where ent.resource.resourceType ="Organization"
create (org: Organization {name: ent.resource.name, orgtype: ent.resource.type[0].coding[0].display
, id: ent.resource.id, addressCity: ent.resource.address[0].city, addressState: ent.resource.address[0].state,
 addressLine: ent.resource.address[0].line[0]})

#Encounter Node
call apoc.load.json("a.json") yield value unwind value.entry as ent
with ent
where ent.resource.resourceType ="Encounter"
create (enc: Encounter {type: ent.resource.class.code, id: ent.resource.id, provider: ent.resource.participant[0].individual.reference, 
encstart: ent.resource.period.start,
encend: ent.resource.period.end, 
id: ent.resource.id, 
pid: ent.resource.subject.reference,
status: ent.resource.status,
orgid: ent.resource.serviceProvider.reference
})

#Condition
call apoc.load.json("a.json") yield value unwind value.entry as ent
with ent
where ent.resource.resourceType ="Condition"
create (c: Condition {
type: ent.resource.resourceType, 
id: ent.resource.id, 
clinicalstatus: ent.resource.clinicalstatus.coding[0].code, 
verificationstatus: ent.resource.verificationStatus.coding[0].code,
conditioncode: ent.resource.code.text,
pid: ent.resource.subject.reference,
encref: ent.resource.encounter.reference,
onsetdate: ent.resource.onsetDateTime,
recordeddata: ent.resource.recordedDate
})

#Observation
call apoc.load.json("a.json") yield value unwind value.entry as ent
with ent
where ent.resource.resourceType ="Observation"
create (obs: Observation {
id: ent.resource.id, 
obscategory: ent.resource.category[0].coding[0].display, 
obstext: ent.resource.code.text, 
encid: ent.resource.encounter.reference, 
obstimedate: ent.resource.effectiveDateTime, 
obsvalue: ent.resource.valueQuantity.value,
obsunit: ent.resource.valueQuantity.unit,
obscode: ent.resource.valueQuantity.code,
pid: ent.resource.subject.reference})


#MedicationRequest
call apoc.load.json("a.json") yield value unwind value.entry as ent
with ent
where ent.resource.resourceType ="MedicationRequest"
create (medrequest: MedicationRequest {
id: ent.resource.id, 
status: ent.resource.status,
intent: ent.resource.intent,
codingdisplaytext: ent.resource.medicationCodeableConcept.text,
codingdisplaycode: ent.resource.medicationCodeableConcept.coding[0].code,
pid: ent.resource.subject.reference,
encid: ent.resource.encounter.reference,
reasonid: ent.resource.reasonReference[0].reference,
requesterid: ent.resource.requester.reference,
authoredon: ent.resource.authoredOn
})


#Procedure
call apoc.load.json("a.json") yield value unwind value.entry as ent
with ent
where ent.resource.resourceType ="Procedure"
create (pr: Procedure {
id: ent.resource.id, 
status: ent.resource.status,
intent: ent.resource.intent,
codingdisplaytext: ent.resource.code.text,
pid: ent.resource.subject.reference,
encid: ent.resource.encounter.reference,
reasonid: ent.resource.reasonReference[0].reference,
startdate: ent.resource.performedPeriod.start,
enddate: ent.resource.performedPeriod.stop
})


## Build relationships

match (p:Patient),(e:Encounter) where e.pid contains p.id CREATE (p)-[r:HASENCOUNTER]->(e)
RETURN type(r);

match (o: Observation),(e: Encounter) where o.encid contains e.id CREATE (e)-[r:HASOBSERVATION]->(o)
RETURN type(r);

match (c: Condition),(e: Encounter) where c.encref contains e.id CREATE (e)-[r:REVEALEDCONDITION]->(c)
RETURN type(r);

match (c: Condition),(p: Patient) where c.pid contains p.id CREATE (p)-[r:CONDITION {date: c.onsetdate}]->(c)
RETURN type(r);

MATCH (c:Condition), (p:Patient) where c.pid contains p.id 
WITH c, p ORDER BY c.onsetdate ASC LIMIT 1
CREATE (p)-[r:FIRSTCONDITION {date: c.onsetdate}]->(c)
RETURN type(r);

MATCH (c:Condition), (p:Patient) where c.pid contains p.id 
WITH c, p ORDER BY c.onsetdate DESC LIMIT 1
CREATE (p)-[r:LATESTCONDITION {date: c.onsetdate}]->(c)
RETURN type(r);
 
match (c: Condition),(mr: MedicationRequest) where mr.reasonid contains c.id CREATE (mr)-[r:TREATMENTFOR]->(c)
RETURN type(r);

match (c: Condition),(pr: Procedure) where pr.reasonid contains c.id  CREATE (pr)-[r:PROCEDUREFORTREATMENT]->(c)
RETURN type(r);

match (e: Encounter),(pr: Procedure) where pr.encid contains e.id  CREATE (pr)-[r:PROCEDUREINENCOUNTER]->(c)
RETURN type(r);


##Similarity based on conditions by Cosine similarity function
MATCH(p:Patient)
   with p
CALL {
    with p
    MATCH (p)-[:CONDITION]-(c)
    WITH p,[c.conditioncode,(((duration.between(datetime(p.birthDate),datetime(c.onsetdate))).years)/10),
	c.verificationstatus, c.clinicalstatus] as embedding  
      UNWIND embedding AS embed
      WITH collect(DISTINCT(embed)) AS conditions
      RETURN conditions
      }
    WITH p, conditions
    WITH p, p.id AS patientId, conditions  AS medical_history
    WITH p, medical_history, [patientId, medical_history] AS pair
    WITH collect(pair) AS pairs1, collect(pair) AS pairs2
    WITH pairs1, pairs2, [] AS complete
    UNWIND pairs1 AS pair1
    UNWIND pairs2 AS pair2
    WITH pair1[0] AS id1, pair2[0] AS id2, pair1[1] AS history1, pair2[1] AS history2
    where  id1 <> id2
    CALL { 
      WITH id1, history1, id2, history2
      
      WITH DISTINCT(history1+history2) AS list, history1, history2
      WITH gds.alpha.ml.oneHotEncoding(list, history1) AS list1, gds.alpha.ml.oneHotEncoding(list, history2) AS list2, history1, history2      
      RETURN gds.alpha.similarity.cosine(list1, list2) AS similarity
    }
    RETURN id1, id2, similarity
      ORDER BY similarity DESC



##Similarity based on demographics by cosine function
MATCH(p:Patient)
   with p
CALL {
    with p
    WITH p,[p.sex,p.race,p.ethinicity,(((duration.between(datetime(p.birthDate),datetime())).years)/10)] as embedding  
      UNWIND embedding AS embed
      WITH collect(DISTINCT(embed)) AS demographics
      RETURN demographics
      }
    WITH p, demographics
    WITH p, p.id AS patientId, demographics  AS dems
    WITH p, dems, [patientId, dems] AS pair
    WITH collect(pair) AS pairs1, collect(pair) AS pairs2
    WITH pairs1, pairs2, [] AS complete
    UNWIND pairs1 AS pair1
    UNWIND pairs2 AS pair2
    WITH pair1[0] AS id1, pair2[0] AS id2, pair1[1] AS history1, pair2[1] AS history2
    where  id1 <> id2
    CALL { 
      WITH id1, history1, id2, history2
      
      WITH DISTINCT(history1+history2) AS list, history1, history2
      WITH gds.alpha.ml.oneHotEncoding(list, history1) AS list1, gds.alpha.ml.oneHotEncoding(list, history2) AS list2, history1, history2
      RETURN gds.alpha.similarity.cosine(list1, list2) AS similarity
    }
   
    RETURN id1, id2, similarity
      ORDER BY similarity DESC

## Similarity based on Condition-medication by cosine function
MATCH(p:Patient)
   with p
CALL {
    with p
    MATCH (p)-[:CONDITION]-(c)-[:TREATMENTFOR]-(m)
    
       WITH p,[c.conditioncode,(((duration.between(datetime(p.birthDate),datetime(c.onsetdate))).years)/10),c.verificationstatus, c.clinicalstatus,m.codingdisplaycode,m.intent,m.status,
       duration.between(datetime(c.onsetdate),datetime(m.authoredOn))] as embedding 
      UNWIND embedding AS embed
      WITH collect(DISTINCT(embed)) AS meds
      RETURN meds
      }
   WITH p, p.id AS patientId, meds  AS medical_history
    WITH p, medical_history, [patientId, medical_history] AS pair
    WITH collect(pair) AS pairs1, collect(pair) AS pairs2
    WITH pairs1, pairs2, [] AS complete
    UNWIND pairs1 AS pair1
    UNWIND pairs2 AS pair2
    WITH pair1[0] AS id1, pair2[0] AS id2, pair1[1] AS history1, pair2[1] AS history2
    where  id1 <> id2
    CALL { 
      WITH id1, history1, id2, history2
      
      WITH DISTINCT(history1+history2) AS list, history1, history2
      WITH gds.alpha.ml.oneHotEncoding(list, history1) AS list1, gds.alpha.ml.oneHotEncoding(list, history2) AS list2, history1, history2      
      RETURN gds.alpha.similarity.cosine(list1, list2) AS similarity
    }
    RETURN id1, id2, similarity
      ORDER BY similarity DESC


## Similarity based on Encounter-observation by cosine function

MATCH(p:Patient)
   with p
CALL {
    with p
    MATCH (p)-[:HASENCOUNTER]-(e)-[:HASOBSERVATION]-(o)
    where o.obscategory <> "vital-signs"
    WITH p,[o.obscategory,o.obscode,o.obsvalue,e.type,(((duration.between(datetime(p.birthDate),datetime(e.encstart))).years)/10)] as embedding  
      UNWIND embedding AS embed
      WITH collect(DISTINCT(embed)) AS encounterObs
      RETURN encounterObs
      }
      WITH p, p.id AS patientId, encounterObs  AS medical_history
    WITH p, medical_history, [patientId, medical_history] AS pair
    WITH collect(pair) AS pairs1, collect(pair) AS pairs2
    WITH pairs1, pairs2, [] AS complete
    UNWIND pairs1 AS pair1
    UNWIND pairs2 AS pair2
    WITH pair1[0] AS id1, pair2[0] AS id2, pair1[1] AS history1, pair2[1] AS history2
    where  id1 <> id2
    CALL { 
      WITH id1, history1, id2, history2
      
      WITH DISTINCT(history1+history2) AS list, history1, history2
      WITH gds.alpha.ml.oneHotEncoding(list, history1) AS list1, gds.alpha.ml.oneHotEncoding(list, history2) AS list2, history1, history2      
      RETURN gds.alpha.similarity.cosine(list1, list2) AS similarity
    }
    RETURN id1, id2, similarity
      ORDER BY similarity DESC
