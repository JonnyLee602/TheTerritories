import type { Officer } from '../types';

interface SidebarProps {
  officer: Officer | null;
  currentPage: string;
  onPageChange: (page: string) => void;
  isAdmin?: boolean;
}

const baseNavItems = [
  { id: 'dashboard', label: 'Dashboard', icon: '◈' },
  { id: 'citizens', label: 'Citizen Lookup', icon: '◉' },
  { id: 'records', label: 'Criminal Records', icon: '⊚' },
  { id: 'warrants', label: 'Warrants', icon: '⊡' },
  { id: 'bolos', label: 'BOLOs', icon: '▣' },
  { id: 'reports', label: 'Reports', icon: '▤' },
];

const adminNavItem = { id: 'staff', label: 'Management', icon: '⚙' };

export function Sidebar({ officer, currentPage, onPageChange, isAdmin }: SidebarProps) {
  const navItems = isAdmin ? [...baseNavItems, adminNavItem] : baseNavItems;
  return (
    <div className="w-64 flex flex-col border-r border-zinc-800" style={{ background: 'linear-gradient(180deg, #18181b 0%, #0f0f10 100%)' }}>
      {/* Header */}
      <div className="p-4 border-b border-zinc-800">
        <h2 className="text-zinc-400 text-xs uppercase tracking-wider">Navigation</h2>
      </div>

      {/* Officer Info */}
      {officer && (
        <div className="p-4 border-b border-zinc-800 bg-zinc-900/50">
          <p className="text-white text-sm font-medium">{officer.name}</p>
          <p className="text-amber-400 text-xs mt-0.5">{officer.job?.label || 'Law Enforcement'}</p>
          <p className="text-zinc-500 text-xs">{officer.job?.grade?.name || 'Officer'}</p>
        </div>
      )}

      {/* Navigation */}
      <nav className="flex-1 py-4">
        {navItems.map((item) => (
          <button
            key={item.id}
            onClick={() => onPageChange(item.id)}
            className={`w-full px-4 py-3 flex items-center gap-3 text-left transition-all ${
              currentPage === item.id
                ? 'bg-amber-600/20 text-white border-l-2 border-amber-500'
                : 'text-zinc-400 hover:bg-zinc-800/50 hover:text-zinc-200'
            }`}
          >
            <span className="text-sm">{item.icon}</span>
            <span className="text-sm" style={{ fontFamily: 'var(--font-display)' }}>{item.label}</span>
          </button>
        ))}
      </nav>

      {/* Footer */}
      <div className="p-4 border-t border-zinc-800">
        <p className="text-zinc-700 text-xs text-center">RSG Framework</p>
      </div>
    </div>
  );
}
