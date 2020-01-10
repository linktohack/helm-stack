```bash
helm -n com-linktohack-redmine upgrade --install redmine --set services.redmine.ports={3000:3000},services.db.ports={3306:3306} .
```