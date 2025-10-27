export default function About() {
  return (
    <div className="min-h-screen bg-background">
      <div className="mx-auto max-w-4xl px-4 py-8">
        <div className="rounded-lg border bg-card p-8 shadow-sm">
          <h1 className="mb-6 text-3xl font-bold">
            About Ohio State Nightlife Map
          </h1>

          <div className="prose prose-slate max-w-none">
            <p className="mb-6 text-lg text-muted-foreground">
              Welcome to Ohio State Nightlife Map - your ultimate guide to
              discovering the best nightlife spots around Ohio State University!
            </p>

            <h2 className="mb-4 text-2xl font-semibold">What We Do</h2>
            <p className="mb-4 text-muted-foreground">
              Our platform helps Ohio State students find and share information
              about local bars, clubs, events, and social gatherings happening
              around campus. Whether you're looking for a quiet pub to study in
              or an energetic club to dance the night away, we've got you
              covered.
            </p>

            <h2 className="mb-4 text-2xl font-semibold">Features</h2>
            <ul className="mb-6 list-inside list-disc space-y-2 text-muted-foreground">
              <li>Interactive Ohio State campus map with venue locations</li>
              <li>Real-time check-ins and activity updates</li>
              <li>Event listings and special promotions</li>
              <li>Student reviews and ratings</li>
              <li>Social features to connect with friends</li>
              <li>
                Organized by campus areas: North Campus, South Campus, and Short
                North
              </li>
            </ul>

            <div className="rounded-lg bg-muted p-6">
              <h3 className="mb-2 text-xl font-semibold">Coming Soon</h3>
              <p className="text-muted-foreground">
                We're constantly working to improve your experience. Stay tuned
                for new features including group planning, event
                recommendations, and more!
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
