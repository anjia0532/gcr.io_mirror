_PROCESS_PIPE_NAME="/tmp/$(cat /proc/sys/kernel/random/uuid)"
_PROCESS_PIPE_ID=10

function _create_pipe()
{

  mkfifo ${_PROCESS_PIPE_NAME}
  eval exec "${_PROCESS_PIPE_ID}""<>${_PROCESS_PIPE_NAME}"

  for ((i=0; i< $1; i++))
  do
    echo >&${_PROCESS_PIPE_ID}
  done
}

function process_init()
{
  _create_pipe $1
}

function process_run()
{
  cmd=$1
  
  if [ -z "$cmd" ]; then
    echo "please input command to run"
    exit 1
  fi
  
  read -u${_PROCESS_PIPE_ID}
  {
    $cmd
    echo >&${_PROCESS_PIPE_ID}
  }&
}
 