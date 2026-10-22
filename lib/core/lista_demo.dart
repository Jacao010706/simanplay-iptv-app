import '../models/app_session.dart';
import '../models/category.dart';
import '../models/channel.dart';
import '../models/movie.dart';
import 'loja.dart';

/// Lista de demonstração da versão Google Play: deixa o revisor (ou quem ainda não tem lista)
/// usar o app sem lista própria. Só filmes abertos da Blender Foundation, com licença Creative
/// Commons, tocados direto do Wikimedia Commons (e dois streams HLS públicos de teste dos mesmos
/// filmes, como "canais").
///
/// Funciona como um provedor Xtream que responde no próprio aparelho: a sessão usa [host]
/// (domínio `.invalid`, que nunca resolve) e o `XtreamService` devolve os dados daqui, sem rede.
/// Nada é enviado ao nosso servidor.
class ListaDemo {
  static const host = 'https://demo.sofae.invalid';
  static const usuario = 'demo';
  static const senha = 'demo';
  static const nome = 'Demonstração (conteúdo livre)';

  /// Só a Play tem a demonstração; no APK do painel o compilador descarta tudo.
  static bool ativa(String? host) => Loja.play && host == ListaDemo.host;

  static AppSession sessao() => AppSession.xtream(host: host, username: usuario, password: senha);

  static const creditos = 'Filmes abertos © Blender Foundation (blender.org), licenças Creative Commons '
      'indicadas em cada título. Vídeos e imagens servidos pelo Wikimedia Commons.';

  static final categoriasCanais = [Category(id: 'demo_canais', name: nome, type: 'live')];
  static final categoriasFilmes = [Category(id: 'demo_filmes', name: 'Filmes abertos da Blender (CC)', type: 'movie')];

  static const _commons = 'https://upload.wikimedia.org/wikipedia/commons/transcoded';
  static const _thumbs = 'https://thumb.wikimedia.org/wikipedia/commons/thumb';

  static String _video(String caminho, String arquivo) => '$_commons/$caminho/$arquivo/$arquivo.480p.vp9.webm';
  static String _capa(String caminho, String arquivo) => '$_thumbs/$caminho/$arquivo/330px--$arquivo.jpg';

  static final filmesInfo = <FilmeDemo>[
    FilmeDemo('demo_bbb', 'Big Buck Bunny', 2008, 'CC BY 3.0', 'c/c0', 'Big_Buck_Bunny_4K.webm',
        'Um coelho gigante e gentil decide dar o troco em três roedores que atormentam os bichos da floresta.'),
    FilmeDemo('demo_ed', 'Elephants Dream', 2006, 'CC BY 2.5', 'a/a2', 'Elephants_Dream_%282006%29.webm',
        'Dois homens percorrem uma máquina infinita e estranha, que cada um enxerga de um jeito.'),
    FilmeDemo('demo_sintel', 'Sintel', 2010, 'CC BY 3.0', 'f/f1', 'Sintel_movie_4K.webm',
        'Uma jovem atravessa terras perigosas em busca do filhote de dragão que criou.'),
    FilmeDemo('demo_tos', 'Tears of Steel', 2012, 'CC BY 3.0', '1/10',
        'Tears_of_Steel_in_4k_-_Official_Blender_Foundation_release.webm',
        'Em uma Amsterdã do futuro, cientistas tentam salvar o mundo de robôs gigantes.'),
    FilmeDemo('demo_cosmos', 'Cosmos Laundromat', 2015, 'CC BY-SA 3.0', '3/36',
        'Cosmos_Laundromat_-_First_Cycle_-_Official_Blender_Foundation_release.webm',
        'Uma ovelha desanimada recebe de um vendedor misterioso a chance de viver outras vidas.'),
    FilmeDemo('demo_caminandes', 'Caminandes: Gran Dillama', 2013, 'CC BY-SA 3.0', '8/8b',
        'Caminandes%2C_Gran_Dillama_-_Blender_Foundation.webm',
        'A lhama Koro tenta, de todo jeito, chegar ao pasto do outro lado da cerca.'),
    FilmeDemo('demo_spring', 'Spring', 2019, 'CC BY 4.0', 'a/a5', 'Spring_-_Blender_Open_Movie.webm',
        'Uma pastora e seu cão enfrentam espíritos antigos para que a primavera volte.'),
    FilmeDemo('demo_coffee', 'Coffee Run', 2020, 'CC BY 4.0', '3/3f', 'Coffee_Run_-_Blender_Open_Movie-full_movie.webm',
        'Movida a cafeína, uma jovem corre pelas lembranças de um amor que acabou.'),
    FilmeDemo('demo_sprite', 'Sprite Fright', 2021, 'CC BY 4.0', '7/76',
        'Sprite_Fright_-_Blender_Open_Movie-full_movie.webm',
        'Adolescentes acampando na floresta descobrem que os pequenos seres do musgo não são tão fofos.'),
    FilmeDemo('demo_charge', 'Charge', 2022, 'CC BY 4.0', '7/7a', 'Charge_-_Blender_Open_Movie-full_movie.webm',
        'Em um mundo sem energia, uma velha caçadora tenta roubar a última bateria da cidade.'),
  ];

  static List<Movie> get filmes => [
        for (final f in filmesInfo)
          Movie(
            id: f.id,
            name: f.titulo,
            streamUrl: _video(f.caminho, f.arquivo),
            posterUrl: _capa(f.caminho, f.arquivo),
            categoryId: categoriasFilmes.first.id,
            categoryName: categoriasFilmes.first.name,
            plot: f.sinopse,
            releaseDate: '${f.ano}',
            extension: 'webm',
          ),
      ];

  /// "Canais" de demonstração: os mesmos filmes abertos, em HLS (como um canal ao vivo).
  static List<Channel> get canais => [
        Channel(
          id: 'demo_canal_1',
          name: 'Demo 1 · Big Buck Bunny',
          streamUrl: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
          logoUrl: _capa('c/c0', 'Big_Buck_Bunny_4K.webm'),
          categoryId: categoriasCanais.first.id,
          categoryName: categoriasCanais.first.name,
        ),
        Channel(
          id: 'demo_canal_2',
          name: 'Demo 2 · Tears of Steel',
          streamUrl:
              'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
          logoUrl: _capa('1/10', 'Tears_of_Steel_in_4k_-_Official_Blender_Foundation_release.webm'),
          categoryId: categoriasCanais.first.id,
          categoryName: categoriasCanais.first.name,
        ),
        Channel(
          id: 'demo_canal_3',
          name: 'Demo 3 · Sintel',
          streamUrl: _video('f/f1', 'Sintel_movie_4K.webm'),
          logoUrl: _capa('f/f1', 'Sintel_movie_4K.webm'),
          categoryId: categoriasCanais.first.id,
          categoryName: categoriasCanais.first.name,
        ),
      ];

  /// Resposta no formato do get_vod_info do Xtream (a tela de detalhes lê `info`).
  static Map<String, dynamic> infoFilme(String id) {
    final f = filmesInfo.where((f) => f.id == id).firstOrNull;
    if (f == null) return {};
    return {
      'info': {
        'plot': '${f.sinopse}\n\n© Blender Foundation · ${f.licenca} · via Wikimedia Commons',
        'releaseDate': '${f.ano}',
        'genre': 'Animação (filme aberto)',
      },
    };
  }
}

class FilmeDemo {
  final String id;
  final String titulo;
  final int ano;
  final String licenca;
  final String caminho; // pasta no Wikimedia Commons (ex.: c/c0)
  final String arquivo; // nome do arquivo, já codificado para URL
  final String sinopse;
  const FilmeDemo(this.id, this.titulo, this.ano, this.licenca, this.caminho, this.arquivo, this.sinopse);
}
