import { Link } from "react-router-dom";
import { Button } from "@/components/ui/Button";

export default function NotFound() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background">
      <div className="text-center">
        <div className="mb-8">
          <h1 className="text-9xl font-bold text-primary/20">404</h1>
          <h2 className="mb-4 text-3xl font-semibold">Page Not Found</h2>
          <p className="mx-auto mb-8 max-w-md text-muted-foreground">
            Sorry, we couldn't find the page you're looking for. It might have
            been moved, deleted, or doesn't exist.
          </p>
        </div>

        <div className="space-y-4">
          <Button asChild size="lg">
            <Link to="/">Go Home</Link>
          </Button>
          <div>
            <button
              onClick={() => window.history.back()}
              className="text-muted-foreground transition-colors hover:text-foreground"
            >
              ← Go Back
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
