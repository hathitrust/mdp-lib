docker compose run --rm test cover -t -ignore_re='^t' -make 'prove -I. -r t; exit $?'

