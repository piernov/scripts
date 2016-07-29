echo "date;time;state;energy;energy_full;energy_rate;voltage;time_to_empty;percentage;capacity"

while true; do
	current_date=$(date "+%D")
	current_time=$(date "+%T")
	upower="$(upower -i /org/freedesktop/UPower/devices/battery_BAT1)"
	state=$(echo "${upower}" | grep "state:" | sed "s/    state:               //")
	energy=$(echo "${upower}" | grep "energy:" | sed "s/    energy:              //" | sed "s/ Wh//")
	energy_full=$(echo "${upower}" | grep "energy-full:" | sed "s/    energy-full:         //" | sed "s/ Wh//")
	energy_rate=$(echo "${upower}" | grep "energy-rate:" | sed "s/    energy-rate:         //" | sed "s/ W//")
	voltage=$(echo "${upower}" | grep "voltage:" | sed "s/    voltage:             //" | sed "s/ V//")
	time_to_empty=$(echo "${upower}" | grep "time to empty:" | sed "s/    time to empty:       //")
	percentage=$(echo "${upower}" | grep "percentage:" | sed "s/    percentage:          //")
	capacity=$(echo "${upower}" | grep "capacity:" | sed "s/    capacity:            //")
	echo "${current_date};${current_time};${state};${energy};${energy_full};${energy_rate};${voltage};${time_to_empty};${percentage};${capacity}"
	sleep 5
done
