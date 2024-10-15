package Conta;
use strict;
use warnings;
use JSON;

sub new {
    my ($class, $db, $id) = @_;
    my $self = {
        db => $db,
        id => $id,
    };
    
    bless $self, $class;
    return $self;
}

# Carregar dados da conta
sub carregar {
    my $self = shift;
    my $sth = $self->{db}->prepare("SELECT nome, saldo, movimentacoes FROM contas WHERE id = ?");
    $sth->execute($self->{id});
    my ($nome, $saldo, $movimentacoes) = $sth->fetchrow_array;
    return unless $nome;  # Retorna undef se a conta não existir
    $self->{nome} = $nome;
    $self->{saldo} = $saldo;
    $self->{movimentacoes} = decode_json($movimentacoes);
}

# Criar uma nova conta (corrente ou poupança)
sub criar {
    my ($class, $db, $nome, $tipo) = @_;
    my $sth = $db->prepare("INSERT INTO contas (nome, tipo, saldo, movimentacoes) VALUES (?, ?, ?, ?)");
    $sth->execute($nome, $tipo, 0, '[]');
}

# Adicionar uma movimentação (deposito ou saque)
sub adicionar_movimentacao {
    my ($self, $tipo, $valor) = @_;
    my $saldo_atual = $self->{saldo};

    if ($tipo eq 'deposito') {
        $saldo_atual += $valor;
    } elsif ($tipo eq 'saque') {
        return 'Saldo insuficiente' if $saldo_atual < $valor;
        $saldo_atual -= $valor;
    } else {
        return 'Tipo de movimentacao invalido';
    }

    # Atualizar as movimentações
    my $nova_movimentacao = {
        tipo => $tipo,
        valor => $valor,
        data => scalar localtime,
    };
    push @{$self->{movimentacoes}}, $nova_movimentacao;

    # Salvar no banco de dados
    my $sth = $self->{db}->prepare("UPDATE contas SET saldo = ?, movimentacoes = ? WHERE id = ?");
    $sth->execute($saldo_atual, encode_json($self->{movimentacoes}), $self->{id});
    
    return 'Movimentacao registrada com sucesso';
}

# Retornar saldo e movimentações
sub obter_dados {
    my $self = shift;
    return {
        nome => $self->{nome},
        saldo => $self->{saldo},
        movimentacoes => $self->{movimentacoes},
    };
}

1;
