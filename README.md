# Domain-Investigator
## Check the domain date validity and it's SSL certificate validity and makes a cronjob to send the results via emails each month

### ***Prerequisites:***

**1)** Being logged in as root or super-user

**3)** An internet domain pointing to your server, I recommend installing an SPF/DMARC record to pass through some email provider when sending your notifications.

That's it!

### ***What's next:***

**1)** Install the Domain-Investigator.sh file and make it executable.

To install it: 
```bash
wget https://raw.githubusercontent.com/KeepSec-Technologies/Domain-Investigator/main/Domain-Investigator.sh
```
To make it executable:
```bash
chmod +x Domain-Investigator.sh
```
**2)** Then run: 
```bash
sudo ./KPing.sh
```

**3)** Answer the questions like the image below and you're good to go!

![image](https://user-images.githubusercontent.com/108779415/210590813-b6907686-8f07-458e-a6c9-5b42e2151aab.png)

*And we're done!*


The cronjob is in **/etc/cron.d/Domain-Investigator.sh-cron** 

The cronjob logs is in **/var/log/[DOMAIN]-investig-cron.log**

If you want to uninstall completely it do:
```bash
rm -f /etc/cron.d/Domain-Investigator.sh-cron
rm -f /var/log/[DOMAIN]-investig-cron.log
rm -f ./Domain-Investigator.sh
```

Feel free to modify the code if there's something that you want to change.
