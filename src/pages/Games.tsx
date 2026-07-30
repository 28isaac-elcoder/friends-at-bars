import { Link } from "react-router-dom";
import { Card } from "@/components/ui/Card";
import { cn } from "@/lib/utils";
import { ENABLE_DEV_TEST_MODE_UI } from "@/config/devTestMode";

type GameTile = {
  id: number;
  title: string;
  path?: string;
  image?: string;
};

/** Shipped on production Games hub. */
const productionGames: GameTile[] = [
  {
    id: 1,
    title: "Switch Search",
    path: "/games/switch-search",
    image: "/images/games/switchsearchpic.png",
  },
];

/** WIP games — only listed when ENABLE_DEV_TEST_MODE_UI is on. */
const testOnlyGames: GameTile[] = [
  { id: 2, title: "Mega Toe", path: "/games/mega-toe" },
  { id: 3, title: "Ride the Bus", path: "/games/ride-the-bus" },
];

const games: GameTile[] = ENABLE_DEV_TEST_MODE_UI
  ? [...productionGames, ...testOnlyGames]
  : productionGames;

export default function Games() {
  const handleTileClick = (gameId: number) => {
    console.log(`Clicked game ${gameId} (animation test)`);
  };

  return (
    <div className="min-h-screen bg-background">
      <div className="mx-auto max-w-6xl px-4 py-8">
        <h1 className="mb-8 text-3xl font-bold text-foreground">Games</h1>

        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2">
          {games.map((game) => {
            const hasPath = Boolean(game.path);
            const TileContent = (
              <Card
                className={cn(
                  "group relative flex flex-col overflow-hidden transition-all duration-200",
                  "hover:scale-105 hover:shadow-lg",
                  "active:scale-95",
                  "cursor-pointer"
                )}
                onClick={() => !hasPath && handleTileClick(game.id)}
              >
                <div className="relative flex aspect-[4/3] w-full items-center justify-center bg-white overflow-hidden">
                  {game.image ? (
                    <img
                      src={game.image}
                      alt={game.title}
                      className="max-h-full max-w-full object-contain"
                    />
                  ) : (
                    <span className="text-muted-foreground">Image Placeholder</span>
                  )}
                </div>

                <div className="border border-border rounded-md bg-card p-4 mx-4 mb-4">
                  <h3 className="text-lg font-semibold text-foreground text-center">
                    {game.title}
                  </h3>
                </div>
              </Card>
            );

            if (game.path) {
              return (
                <Link key={game.id} to={game.path} className="block">
                  {TileContent}
                </Link>
              );
            }

            return <div key={game.id}>{TileContent}</div>;
          })}
        </div>
      </div>
    </div>
  );
}
