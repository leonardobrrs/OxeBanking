use Mojolicious::Lite;
use lib 'lib';  
use DB;
use Conta;

# Conectar ao banco de dados
helper db => sub {
    state $db = DB->new->db;
};

# Rota para exibir saldo e movimentações
get '/conta/:id' => sub {
    my $c = shift;
    my $id = $c->param('id');

    my $conta = Conta->new($c->db, $id);
    $conta->carregar or return $c->render(text => 'Conta nao encontrada');

    my $dados = $conta->obter_dados;
    $c->render(json => $dados);
};

# Adicionar movimentação
post '/conta/:id/movimentacao' => sub {
    my $c = shift;
    my $id = $c->param('id');
    my $tipo = $c->param('tipo');
    my $valor = $c->param('valor');

    my $conta = Conta->new($c->db, $id);
    $conta->carregar or return $c->render(text => 'Conta nao encontrada');

    my $mensagem = $conta->adicionar_movimentacao($tipo, $valor);
    $c->render(json => { mensagem => $mensagem });
};

# Rota para abrir uma nova conta
post '/conta/abrir' => sub {
    my $c = shift;
    my $nome = $c->param('nome');
    my $tipo = $c->param('tipo');  # "corrente" ou "poupanca"
    
    my $email = $c->param('email');
    my $senha = $c->param('senha');

    unless (validar_senha($senha)) {
        return $c->render(json => { mensagem => 'Senha inválida' }, status => 400);
    }

    Conta->criar($c->db, $nome, $tipo, $email, $senha);
    $c->render(json => { mensagem => 'Conta criada com sucesso' });
};

sub validar_senha {
    my $senha = shift;
    return length($senha) >= 8 && $senha =~ /\d/ && $senha =~ /\W/;
}

app->start;
