# grapfhir
This is an attempt to load FHIR R4 json files into a graph data model

Current data loading is simple per patient.
Here we link patient with conditions, encounters, medications, procedures, observations.
![](images/patient_clinical_graph.PNG)

but my aim is to build cross patient grapth with temporal,status labeled relationship with conditions, medications, procedures, encounters and observations.
![](images/all_patient_clinical_graph.PNG)
