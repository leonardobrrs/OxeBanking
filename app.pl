use Mojolicious::Lite;
use lib 'lib';  
use DB;
use Conta;

# Conectar ao banco de dados
helper db => sub {
    state $db = DB->new->db;
};

# Configurar sessões (com um segredo simples para assinatura de cookies)
app->secrets(['um_segredo_muito_forte']);

# Função para verificar se o usuário está logado
helper is_logged_in => sub {
    my $c = shift;
    return $c->session('conta_id');
};

# Função para verificar se o usuário está autorizado a acessar a conta
helper is_authorized => sub {
    my ($c, $id) = @_;
    return $c->is_logged_in && $c->session('conta_id') == $id;
};

# Rota para login com mensagem
post '/login' => sub {
    my $c = shift;
    my $email = $c->param('email');
    my $senha = $c->param('senha');

    my $sth = $c->db->prepare("SELECT id, nome, senha FROM contas WHERE email = ?");
    $sth->execute($email);
    my ($id, $nome, $senha_armazenada) = $sth->fetchrow_array;

    unless ($id && $senha eq $senha_armazenada) {
        return $c->render(json => { mensagem => 'Email ou senha invalidos' }, status => 401);
    }

    # Iniciar a sessão
    $c->session(conta_id => $id);
    $c->render(json => { mensagem => "Login efetuado com sucesso, bem-vindo $nome" });
};

# Rota para logout
get '/logout' => sub {
    my $c = shift;
    $c->session(expires => 1);  # Expira a sessão
    $c->render(json => { mensagem => 'Logout efetuado com sucesso' });
};

# Rota para abrir uma nova conta e exibir os dados do novo usuário
post '/conta/abrir' => sub {
    my $c = shift;
    my $nome = $c->param('nome');
    my $tipo = $c->param('tipo');  # "corrente" ou "poupanca"
    
    my $email = $c->param('email');
    my $senha = $c->param('senha');

    # Chama a função global validar_senha
    unless (Conta->validar_senha($senha)) {
        return $c->render(json => { mensagem => 'Senha invalida' }, status => 400);
    }

    my $dados_novo_usuario = Conta->criar($c->db, $nome, $tipo, $email, $senha);
    $c->render(json => {
        mensagem => 'Conta criada com sucesso',
        dados => $dados_novo_usuario
    });
};

# Função global para validar a senha
sub validar_senha {
    my $senha = shift;
    return length($senha) >= 8 && $senha =~ /\d/ && $senha =~ /\W/;
}

# Rota para exibir saldo e movimentações (somente para usuário logado)
get '/conta/:id' => sub {
    my $c = shift;
    my $id = $c->param('id');

    # Verifica se o usuário está logado e autorizado
    unless ($c->is_authorized($id)) {
        return $c->render(json => { mensagem => 'Acesso nao autorizado' }, status => 403);
    }

    my $conta = Conta->new($c->db, $id);
    $conta->carregar or return $c->render(text => 'Conta nao encontrada');

    my $dados = $conta->obter_dados;
    $c->render(json => $dados);
};

# Adicionar movimentação (somente para usuário logado)
post '/conta/:id/movimentacao' => sub {
    my $c = shift;
    my $id = $c->param('id');
    my $tipo = $c->param('tipo');
    my $valor = $c->param('valor');

    # Verifica se o usuário está logado e autorizado
    unless ($c->is_authorized($id)) {
        return $c->render(json => { mensagem => 'Acesso nao autorizado' }, status => 403);
    }

    my $conta = Conta->new($c->db, $id);
    $conta->carregar or return $c->render(text => 'Conta nao encontrada');

    my ($mensagem, $saldo_atual) = $conta->adicionar_movimentacao($tipo, $valor);
    $c->render(json => { mensagem => $mensagem, saldo_atual => $saldo_atual });
};

app->start;
