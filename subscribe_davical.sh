USERNAME=piernov
CALENDAR=http://piernov.org/davical/caldav.php/piernov/
REMOTE="http://sco.polytech.unice.fr/1/Telechargements/ical/EdT_Novac_Pierre_Emmanuel.ics?version=13.0.3.2&amp;idICal=3D59B6710A5F2E984E54C54CA2FF2072&amp;param=643d5b312e2e36325d2666683d3126663d31"
CALNAME="Polytech"
curl --basic --user "${USERNAME}" -X BIND -H 'Content-Type: text/xml;charset="UTF-8"' --url "${CALENDAR}" -d "<?xml version=\"1.0\" encoding=\"utf-8\"?><bind xmlns=\"DAV:\"><segment>${CALNAME}</segment><href>${REMOTE}</href></bind>"

