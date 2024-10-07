use Mojolicious::Lite;
use DBI;
use JSON;

# Conectar ao banco de dados
helper db => sub {
    my $self = shift;
    return DBI->connect("dbi:SQLite:dbname=oxe_banking.db","","",{ RaiseError => 1, AutoCommit => 1 });
};

# Rota principal (para exibir saldo e movimentações)
get '/conta/:id' => sub {
    my $c = shift;
    my $id = $c->param('id');

    # Consultar dados da conta no banco de dados
    my $sth = $c->db->prepare("SELECT nome, saldo, movimentacoes FROM contas WHERE id = ?");
    $sth->execute($id);
    my ($nome, $saldo, $movimentacoes) = $sth->fetchrow_array;

    # Se a conta não existir
    return $c->render(text => 'Conta não encontrada') unless $nome;

    # Exibir saldo e movimentações
    my $movimentacoes_list = decode_json($movimentacoes);
    $c->render(json => {
        nome => $nome,
        saldo => $saldo,
        movimentacoes => $movimentacoes_list,
    });
};

# Adicionar movimentação
post '/conta/:id/movimentacao' => sub {
    my $c = shift;
    my $id = $c->param('id');

    # Parâmetros recebidos
    my $tipo = $c->param('tipo');  # "deposito" ou "saque"
    my $valor = $c->param('valor');

    # Consultar a conta no banco de dados
    my $sth = $c->db->prepare("SELECT saldo, movimentacoes FROM contas WHERE id = ?");
    $sth->execute($id);
    my ($saldo_atual, $movimentacoes) = $sth->fetchrow_array;

    # Se a conta não existir
    return $c->render(text => 'Conta não encontrada') unless $saldo_atual;

    # Calcular o novo saldo
    if ($tipo eq 'deposito') {
        $saldo_atual += $valor;
    } elsif ($tipo eq 'saque') {
        return $c->render(text => 'Saldo insuficiente') if $saldo_atual < $valor;
        $saldo_atual -= $valor;
    } else {
        return $c->render(text => 'Tipo de movimentação inválido');
    }

    # Atualizar as movimentações
    my $nova_movimentacao = {
        tipo => $tipo,
        valor => $valor,
        data => scalar localtime,
    };
    my $lista_movimentacoes = decode_json($movimentacoes);
    push @$lista_movimentacoes, $nova_movimentacao;
    my $movimentacoes_atualizadas = encode_json($lista_movimentacoes);

    # Atualizar a conta no banco de dados
    $sth = $c->db->prepare("UPDATE contas SET saldo = ?, movimentacoes = ? WHERE id = ?");
    $sth->execute($saldo_atual, $movimentacoes_atualizadas, $id);

    $c->render(json => { mensagem => 'Movimentação registrada com sucesso', saldo_atual => $saldo_atual });
};


app->start;
