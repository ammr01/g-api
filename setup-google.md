# Setup google api usage via OAuth 2.0: 

- Create new project: <br>
    goto https://console.cloud.google.com/  **>**  ctrl+o  **>**  new project  **>**  write the name, and keep it no organization

- Select the project: <br>
    select the new project if it was not selected from the menu in the upper left corner


- Create App: <br>
    select APIs and services  **>**  select OAuth consent screen  **>**  Get Started  **>**  add your app name, and user support email  **>**  select external  **>**  add contact email  **>**  agree the terms  **>**  finish  **>**  select audiance  **>**  add your email for test users list


- Create creads: <br>
    select APIs and services from navigation menu  **>**  Credentials  **>**  + Create credentials  **>**  OAuth client ID  **>**  select application type "Desktop app"  **>**  write name for the client  **>**  download json file that contains user's details, and save it in the same dir of the script, and do not change the file name


- Enable APIs: <br>
    select APIs and services from navigation menu  **>**  Library  **>**  search for the needed apis, for example gmail and youtube data  **>**  enable api


- Use the library: <br>
    now you can use the use the library after placing the client json file that you downloaded in the same dir of your program, and do not change it is name
