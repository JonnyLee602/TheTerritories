import type { Officer, Stats } from '../types';

interface DashboardProps {
  stats: Stats | null;
  officer: Officer | null;
  onPageChange?: (page: string) => void;
}

export function Dashboard({ stats, officer, onPageChange }: DashboardProps) {
  const statCards = [
    { label: 'Criminal Records', value: stats?.records ?? 0, color: 'from-zinc-800/50 to-zinc-900/50', accent: 'text-white' },
    { label: 'Active Warrants', value: stats?.activeWarrants ?? 0, color: 'from-red-950/50 to-red-900/30', accent: 'text-red-400' },
    { label: 'Active BOLOs', value: stats?.activeBolos ?? 0, color: 'from-orange-950/50 to-orange-900/30', accent: 'text-orange-400' },
    { label: 'Reports Filed', value: stats?.reports ?? 0, color: 'from-blue-950/50 to-blue-900/30', accent: 'text-blue-400' },
    { label: 'Unpaid Fines', value: stats?.unpaidFines ?? 0, color: 'from-amber-950/50 to-amber-900/30', accent: 'text-amber-400' },
  ];

  const quickActions = [
    { label: 'Search Citizen', page: 'citizens' },
    { label: 'File Report', page: 'reports' },
    { label: 'Add BOLO', page: 'bolos' },
    { label: 'Issue Warrant', page: 'warrants' },
  ];

  return (
    <div className="space-y-6">
      {/* Welcome Header */}
      <div className="bg-gradient-to-r from-amber-600/10 to-transparent border border-zinc-800 rounded-lg p-6">
        <h2 className="text-white text-2xl font-bold" style={{ fontFamily: 'var(--font-display)' }}>
          Welcome, {officer?.name || 'Officer'}
        </h2>
        <p className="text-zinc-500 mt-1">Law Enforcement Database</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {statCards.map((stat) => (
          <div
            key={stat.label}
            className={`bg-gradient-to-br ${stat.color} border border-zinc-800 rounded-lg p-4 text-center`}
          >
            <p className={`${stat.accent} text-3xl font-bold`}>{stat.value}</p>
            <p className="text-zinc-500 text-xs mt-2 uppercase tracking-wide">{stat.label}</p>
          </div>
        ))}
      </div>

      {/* Quick Actions */}
      <div className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-6">
        <h3 className="text-white text-lg font-bold mb-4" style={{ fontFamily: 'var(--font-display)' }}>
          Quick Actions
        </h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {quickActions.map((action) => (
            <button
              key={action.page}
              onClick={() => onPageChange?.(action.page)}
              className="bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 rounded p-3 text-zinc-200 text-sm transition-colors"
            >
              {action.label}
            </button>
          ))}
        </div>
      </div>


    </div>
  );
}
