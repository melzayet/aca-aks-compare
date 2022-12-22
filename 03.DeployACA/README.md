## GOAL 3: Deploying to Azure Container Apps
<br/>

#### **A. GRASP THE GOAL:**
Start with the below video:


#### **B. MAKE SURE YOU UNDERSTAND THESE CONCEPTS (STAY FOCUSED ON THE GOAL):**


#### **C. TRY IT YOURSELF (IF POSSIBLE):**
#### 1. Fork this repository
This will allow you to set secret and run your own workflows. Click [here](https://github.com/melzayet/azure-cn-depicted/fork) to fork.

#### 2. Review/Tweak the Bicep file
Navigate to folder "03.DeployACA", and check the file "ContainerApps/bicep/ca-app.bicep". This defines the app deployment for Container Apps and Cosmos DB tables.
Review the file and feel free to change any configuration if needed.

#### 3. Review GitHub workflows
Workflows under ".github/workflows" help automate the deployment of infrastructure and apps:

- Deploy AKS infrastructure: aks-cluster-deploy.yml
- Setup AKS cluster: aks-cluster-setup.yml
- Deploy AKS app: aks-app-deploy.yml
- Setup Container Apps infrastructure: aca-infra-deploy.yml
- Deploy Container Apps application: aca-app-deploy.yml

Review this workflow: "aca-app-deploy.yml"

#### 4. Run the first deployment
Either by commiting changes to GitHub or running workflows [directly](https://docs.github.com/en/actions/managing-workflow-runs/manually-running-a-workflow), we can deploy our app resources

- Cluster setup workflow name: 'Trigger auto deployment for AKS app deployment'
- App deployment workflow name: 'Trigger auto deployment for AKS cluster setup'

#### 5. Run the first deployment
