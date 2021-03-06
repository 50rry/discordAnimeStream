#!/bin/sh


die() {
  err "$*"
  exit 1
}

dep_ch() {
  # checks if programs are present
  for dep; do
    if ! command -v "$dep" >/dev/null; then
      err "Program \"$dep\" not found. Please install it."
      #aria2c is in the package aria2
      if [ "$dep" = "aria2c" ]; then
        err "To install aria2c, Type <your_package_manager> aria2"
      fi
      die
    fi
  done
}

#############
# Searching #
#############

search_anime() {
  # get anime name along with its id for search term
  search=$(printf '%s' "$1" | tr ' ' '-')

  curl -s "$base_url//search.html" \
    -G \
    -d "keyword=$search" |
    sed -n -E '
		s_^[[:space:]]*<a href="/category/([^"]*)" title="([^"]*)".*_\1_p
		'
}

search_eps() {
  # get available episodes for anime_id
  anime_id=$1

  curl -s "$base_url/category/$anime_id" |
    sed -n -E '
		/^[[:space:]]*<a href="#" class="active" ep_start/{
		s/.* '\''([0-9]*)'\'' ep_end = '\''([0-9]*)'\''.*/\2/p
		q
		}
		'
}

##################
# URL processing #
##################

get_dpage_link() {
  # get the download page url
  anime_id=$1
  ep_no=$2

  # credits to fork: https://github.com/Dink4n/ani-cli for the fix
  # dub prefix takes the value "-dub" when dub is needed else is empty
  anime_page=$(curl -s "$base_url/$anime_id-$ep_no")

  if printf '%s' "$anime_page" | grep -q "404"; then
    anime_page=$(curl -s "$base_url/$anime_id-episode-$ep_no")
  fi

  printf '%s' "$anime_page" |
    sed -n -E 's/^[[:space:]]*<a href="#" rel="100" data-video="([^"]*)".*/\1/p' |
    sed 's/^/https:/g'
}

decrypt_link() {
  ajax_url='https://gogoplay.io/encrypt-ajax.php'

  #get the id from the url
  video_id=$(echo "$1" | cut -d\? -f2 | cut -d\& -f1 | sed 's/id=//g')

  #construct ajax parameters
  secret_key='3235373436353338353932393338333936373634363632383739383333323838'
  iv='34323036393133333738303038313335'
  ajax=$(echo "$video_id" | openssl enc -aes256 -K "$secret_key" -iv "$iv" -a)

  #send the request to the ajax url
  curl -s -H 'x-requested-with:XMLHttpRequest' "$ajax_url" -d "id=$ajax" -d "time=69420691337800813569" |
    sed -e 's/\].*/\]/' -e 's/\\//g' |
    grep -Eo 'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)'
}

get_video_quality() {
  # chooses the link for the set quality
  dpage_url="$1"
  video_links=$(decrypt_link "$dpage_url")
  case $quality in
  best)
    video_link=$(printf '%s' "$video_links" | head -n 4 | tail -n 1)
    ;;

  worst)
    video_link=$(printf '%s' "$video_links" | head -n 1)
    ;;

  *)
    video_link=$(printf '%s' "$video_links" | grep -i "${quality}p" | head -n 1)
    if [ -z "$video_link" ]; then
      err "Current video quality is not available (defaulting to best quality)"
      quality=best
      video_link=$(printf '%s' "$video_links" | head -n 4 | tail -n 1)
    fi
    ;;
  esac
  printf '%s' "$video_link"
}

###############
# Text output #
###############

err() {
  # display an error message to stderr (in red)
  printf "%s\n" "$*" >&2
}

inf() {
  # display an informational message (first argument in green, second in magenta)
  printf "%s %s\n" "$1" "$2"
}

prompt() {
  # prompts the user with message in $1-2 ($1 in blue, $2 in magenta) and saves the input to the variables in $REPLY and $REPLY2
  printf "%s %s\n" "$1" "$2"
  read -r REPLY REPLY2
}

menu_line_even() {
  # displays an even (cyan) line of a menu line with $2 as an indicator in [] and $1 as the option
  printf "%s %s\n" "$2" "$1"
}

menu_line_odd() {
  # displays an odd (yellow) line of a menu line with $2 as an indicator in [] and $1 as the option
  printf "%s %s\n" "$2" "$1"
}

menu_line_alternate() {
  menu_line_parity=${menu_line_parity:-0}

  if [ "$menu_line_parity" -eq 0 ]; then
    menu_line_odd "$1" "$2"
    menu_line_parity=1
  else
    menu_line_even "$1" "$2"
    menu_line_parity=0
  fi
}

menu_line_strong() {
  # displays a warning (red) line of a menu line with $2 as an indicator in [] and $1 as the option
  printf "%s %s\n" "$2" "$1"
}

#################
# Input parsing #
#################

anime_selection() {
  count=1
  while read -r anime_id; do
    menu_line_alternate "$anime_id" "$count"
    : $((count += 1))
  done <<-EOF
	$search_results
	EOF
  if [ -n "$ep_choice_to_start" ] && [ -n "$select_first" ]; then
    #tput reset
    choice=1
  elif [ -z "$ep_choice_to_start" ] || { [ -n "$ep_choice_to_start" ] && [ -z "$select_first" ]; }; then
    prompt "Enter number"
    choice="$REPLY $REPLY2"
  fi

  # Check if input is a number
  [ "$choice" -eq "$choice" ] 2>/dev/null || die "Invalid number entered"

  # Select respective anime_id
  count=1
  while read -r anime_id; do
    if [ "$count" -eq "$choice" ]; then
      selection_id=$anime_id
      break
    fi
    count=$((count + 1))
  done <<-EOF
		$search_results
		EOF

  if [ -z "$selection_id" ]; then
    die "Invalid number entered"
  fi

  search_ep_result="$(search_eps "$selection_id")"
  read -r last_ep_number <<-EOF
	$search_ep_result
	EOF
}

episode_selection() {
  # using get_dpage_link to get confirmation from episode 0 if it exists,else first_ep_number becomes "1"
  first_ep_number="0"
  result=$(get_dpage_link "$anime_id" "$first_ep_number")

  if [ -n "$result" ]; then
    true
  else
    first_ep_number="1"
  fi

  if [ "$last_ep_number" -gt "$first_ep_number" ]; then
    if [ -z "$ep_choice_to_start" ]; then
      prompt "Choose episode" "[$first_ep_number-$last_ep_number]"
      ep_choice_start=$REPLY
      ep_choice_end=$REPLY2
    else
      ep_choice_start=$ep_choice_to_start && unset ep_choice_to_start
    fi
    whether_half="$(echo "$ep_choice_start" | cut -c1-1)"
    if [ "$whether_half" = "h" ]; then
      half_ep=1
      ep_choice_start="$(echo "$ep_choice_start" | cut -c2-)"
    fi
  fi

}


check_input() {
  # checks if input is number, creates $episodes from $ep_choice_start and $ep_choice_end
  [ "$ep_choice_start" -eq "$ep_choice_start" ] 2>/dev/null || die "Invalid number entered"
  episodes=$ep_choice_start
  if [ -n "$ep_choice_end" ]; then
    [ "$ep_choice_end" -eq "$ep_choice_end" ] 2>/dev/null || die "Invalid number entered"
    # create list of episodes to download/watch
    episodes=$(seq "$ep_choice_start" "$ep_choice_end")
  fi
}

##################
# Video Playback #
##################

open_selection() {
  # opens selected episodes one-by-one
  for ep in $episodes; do
    open_episode "$selection_id" "$ep"
  done
  episode=${ep_choice_end:-$ep_choice_start}
}

open_episode() {
  anime_id=$1
  episode=$2
  # Cool way of clearing screen
  #tput reset
  # checking if episode is in range
  while [ "$episode" -gt "$last_ep_number" ] || [ -z "$episode" ]; do
    [ "$ep_choice_start" -eq "$ep_choice_start" ] 2>/dev/null || die "Invalid number entered"
    if [ "$last_ep_number" -eq 0 ]; then
      die "Episodes not released yet!"
    else
      err "Episode out of range"
    fi
    prompt "Choose episode" "[$first_ep_number-$last_ep_number]"
    episode="$REPLY $REPLY2"
  done

  inf "Getting data for episode $episode"
  # decrypting url
  dpage_link=$(get_dpage_link "$anime_id" "$episode")
  video_url=$(get_video_quality "$dpage_link")

  killall ffmpeg

  if [ -z "$video_url" ]; then
    die "Video URL not found"
  fi

  inf "Currently playing $selection_id episode" "$episode/$last_ep_number"
  ffmpeg -stream_loop -1 -re -i "$video_url" -vcodec rawvideo -threads 0 -f v4l2 /dev/video2 > /dev/null 2>&1 &
  PULSE_SINK=virtual_speaker ffmpeg -use_wallclock_as_timestamps 1 -i "$video_url" -f pulse "Discord microphone stream" > /dev/null 2>&1 &
}

############
# Start Up #
############

# default options
quality=best
choice=""

while getopts 'viq:dp:chDUVe:a:' OPT; do
  case $OPT in
  h)
    help_text
    exit 0
    ;;
  d)
    is_download=1
    ;;
  a)
    ep_choice_to_start=$OPTARG
    ;;
  D)
    : >"$logfile"
    exit 0
    ;;
  p)
    is_download=1
    download_dir=$OPTARG
    ;;
  e)
    player_arguments=$OPTARG
    ;;
  i)
    player_fn="iina"
    ;;
  q)
    quality=$OPTARG
    ;;
  c)
    scrape=history
    ;;
  v)
    player_fn="vlc"
    ;;
  U)
    update_script
    exit 0
    ;;
  V)
    version_text
    exit 0
    ;;
  *)
    help_text
    exit 1
    ;;
  esac
done

# check for main dependencies
dep_ch "curl" "sed" "grep" "git" "openssl"

shift $((OPTIND - 1))
# gogoanime likes to change domains but keep the olds as redirects
base_url=$(curl -s -L -o /dev/null -w "%{url_effective}\n" https://gogoanime.cm)
prompt "Search Anime"
query="$REPLY $REPLY2"
search_results=$(search_anime "$query")
[ -z "$search_results" ] && die "No search results found"
anime_selection "$search_results"
episode_selection

check_input
open_selection

########
# Loop #
########

while :; do
  if [ -z "$select_first" ]; then
    if [ "$episode" -ne "$last_ep_number" ]; then
      menu_line_alternate "next episode" "n"
    fi
    if [ "$episode" -ne "$first_ep_number" ]; then
      menu_line_alternate "previous episode" "p"
    fi
    if [ "$last_ep_number" -ne "$first_ep_number" ]; then
      menu_line_alternate "select episode" "s"
    fi
    menu_line_alternate "replay current episode" "r"
    menu_line_alternate "search for another anime" "a"
    menu_line_strong "exit" "q"
    prompt "Enter choice"
    # process user choice
    choice="$REPLY"
    case $choice in
    n)
      ep_choice_start=$((episode + 1))
      ep_choice_end=""
      ;;
    p)
      ep_choice_start=$((episode - 1))
      ep_choice_end=""
      ;;

    s)
      episode_selection
      ;;

    r)
      ep_choice_start=$((episode))
      ep_choice_end=""
      ;;
    a)
      #tput reset
      prompt "Search Anime"
      query="$REPLY $REPLY2"
      search_results=$(search_anime "$query")
      [ -z "$search_results" ] && die "No search results found"
      anime_selection "$search_results"
      episode_selection
      ;;
    N)
      ep_choice_start=$((episode + 1))
      ;;
    q)
      break
      ;;

    *)
      #tput reset
      err "invalid choice"
      continue
      ;;
    esac
    check_input
    open_selection

  else
    wait $!
    exit
  fi
done
